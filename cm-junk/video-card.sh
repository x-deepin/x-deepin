#!/bin/bash

set -e

d=$(dirname $0)

bins=$(which hwinfo || :)
if test "x$bins" = "x"; then
	echo "Please install hwinfo package."
	exit 1
fi

bins=$(which sha256sum || :)
if test "x$bins" = "x"; then
	echo "Please install coreutils package."
	exit 1
fi

bins=$(which lsb_release || :)
if test "x$bins" = "x"; then
	echo "Please install lsb-release package."
	exit 1
fi

cards=$(lspci | awk '/VGA|3D|2D/{print $1}')
distributor=$(lsb_release -i -s)

case $distributor in
Debian|Deepin)
	bins=$(which apt-file || :)
	if test "x$bins" = "x"; then
		echo "Please install apt-file."
		exit 1
	fi
	;;
Suse|Redhat)
	bins=$(which rpm || :)
	if test "x$bins" = "x"; then
		echo "Please install rpm."
		exit 1
	fi
	;;
esac

process_section_one() {
    if [ $1 = "gpu" ]; then
        infile="gpu.attr"
    else if [ $1 = "screen" ]; then
            infile="screen.attr"
         fi
    fi

    outfile=""

    for attr in $(cat $infile); do
        if [ $1 = "gpu" ]; then
            tnum=$(echo $attr | sed -ne 's,^gpu##\(.*\),\1,p')
            if [ -n "$tnum" ]; then
                outfile=$tnum
                echo $attr > $outfile
                prev=""
                continue
            fi
        fi

        if [ $1 = "screen" ]; then
            tnum=$(echo $attr | sed -ne 's,^screen##\(.*\),\1,p')
            if [ -n "$tnum" ]; then
                outfile=screen
                echo $attr > $outfile
                prev=""
                continue
            fi
        fi

        tattr=$(echo $attr | sed 's,^.*###.*$,,g')
        if [ -z "$tattr" ]; then
            name=$(echo $attr | sed -ne 's,\(^.*\)###.*$,\1,p')
            value=$(echo $attr | sed -ne 's,^.*###\(.*\)$,\1,p')
            if [ -n "$prev" ] && [ "x$name" != "xplaceholder" ]; then 
                echo >> $outfile
            fi
            if [ "x$name" != "xplaceholder" ]; then
                echo -n $attr >> $outfile
            else
                echo -n $value >> $outfile
            fi
            prev=$name
        fi
    done
}

siattrs="OperatingSystem
  NvidiaDriverVersion
  NvControlVersion
  GLXServerVersion
  GLXClientVersion
  OpenGLVersion
  XRandRVersion
  XF86VidModeVersion
  XvVersion
  TwinView
  InitialPixmapPlacement
  MultiGpuDisplayOwner
  Depth30Allowed
  NoScanout
  AccelerateTrapezoids
  SyncToVBlank
  LogAniso
  FSAA
  TextureSharpen
  TextureClamping
  FXAA
  AllowFlipping
  FSAAAppControlled
  LogAnisoAppControlled
  OpenGLImageSettings
  FSAAAppEnhanced
  SliMosaicModeAvailable
  CUDACores
  GPUMemoryInterface
  GPUCoreTemp
  GPUCurrentClockFreqs
  GPUCurrentPerfLevel
  GPUAdaptiveClockState
  ECCConfigurationSupported
  GPUCurrentClockFreqsString
  GPUPerfModes
  FrameLockAvailable
  GvoSupported
  IsGvoDisplay
  DigitalVibrance
  ImageSharpeningDefault
  ColorSpace
  ColorRange
  XineramaInfoOrder"

giattrs="
  OperatingSystem
  NvidiaDriverVersion
  Depth30Allowed
  NoScanout
  SliMosaicModeAvailable
  TotalDedicatedGPUMemory
  UsedDedicatedGPUMemory
  CUDACores
  GPUMemoryInterface
  GPUCoreTemp
  GPUCurrentClockFreqs
  GPUCurrentPerfLevel
  GPUAdaptiveClockState
  GPUPowerMizerMode
  GPUPowerMizerDefaultMode
  ECCSupported
  ECCConfigurationSupported
  BaseMosaic
  MultiGpuMasterPossible
  VideoEncoderUtilization
  GPUCurrentClockFreqsString
  GPUPerfModes
  FrameLockAvailable
  IsGvoDisplay
  Dithering
  CurrentDithering
  DitheringMode
  CurrentDitheringMode
  DitheringDepth
  CurrentDitheringDepth
  DigitalVibrance
  ImageSharpeningDefault
  ColorSpace
  ColorRange
  SynchronousPaletteUpdates
  Hdmi3D"

process_attributes() {
    infile=$2
    prev=""

    if [ $3 = "screen" ]; then
        iattrs=$siattrs
    fi

    if [ $3 = "gpu" ]; then
        iattrs=$giattrs
    fi

    outfile=$infile.pre
    rm -fr $outfile
    touch $outfile
    for attr in $(cat $infile); do
        name=$(echo $attr | sed -ne 's,\(^.*\)###.*$,\1,p')
        for i in $iattrs; do
            if [ "x"$name = "x"$i ]; then
                echo $attr >> $outfile
                break
            fi
        done
    done
        
    for attr in $(cat $outfile); do
        if [ -n "$prev" ]; then
            echo -n "}, " >> $1
        fi

        name=$(echo $attr | sed -ne 's,\(^.*\)###.*$,\1,p')
        value=$(echo $attr | sed -ne 's,^.*###\(.*\)$,\1,p' | sed 's,%20,\ ,g')
        if [ -n "$name" ]; then
            if [ $name = "GPUPerfModes" ]; then
                echo -n " {\"name\": \"GPUPerfModes\"," >> $1
                value1=$(echo $value | sed 's,\([0-9a-zA-Z]\+\)=\([0-9a-zA-Z]\+\),"\1":"\2",g' | sed 's,\ ;\ ,}\, {,g')
                echo -n "  \"value\": [ {$value1} ]" >> $1
            else
                echo -n " {\"name\": \"$name\"," >> $1
                echo -n "  \"value\": \"$value\"" >> $1
            fi
        fi

        # FIXME, may need to treat GPUCurrentClockFreqsStrings
        # and GPUPerfModes as non string type, maybe array of dict?
        prev=$name
    done

    if [ -n "$prev" ]; then
        echo -n "}" >> $1
    fi
}

collect_nvs_one() {
    ignore_attrs=""
    useful_attrs=""
    card=$2
    LSPCI="lspci"
    NVSET="nvidia-settings"

    if [ $# -eq 3 ]; then
        LSPCI="optirun lspci"
        NVSET="optirun nvidia-settings"
    fi

    # Get gpus
    gpus=$($NVSET -q gpus | sed -ne 's,^[\ \ t]\+\[[0-9]\+\].*\[\(.*\)\]\ *(\(.*\))$,\1::\2,p' | sed 's,\ ,%20,g')
    cards=$($LSPCI | awk '/VGA|2D|3D/{print $0}' | awk '/NVIDIA/{print $0}' | sed -ne 's,\(^[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}\.[0-9a-fA-F]\).*\[\(.*\)\]\ .*$,\1::\2,p' | sed 's,\ ,%20,g')

    if [ -z "$gpus" ]; then
        NVSET="optirun nvidia-settings -c :8"
        gpus=$($NVSET -q gpus | sed -ne 's,^[\ \ t]\+\[[0-9]\+\].*\[\(.*\)\]\ *(\(.*\))$,\1::\2,p' | sed 's,\ ,%20,g')
    fi

    if [ -z "$gpus" ]; then
        echo "Not found gpus for nvidia card."
        echo "    \"Nvidia Settings\": null," >> $1
        return 0
    fi

    $NVSET --query all -t > nvinfo.attr

    cat nvinfo.attr | sed -ne 's,^Attribute.*\.\([0-9]\+\):$,screen##\1,p;
                                        t screen; T;
                                        : screen; n;
                                        s,^[\ \t]\+\(.\{\,35\}\):[\ \t]\+\(.*\)$,\1###\2,p;
                                        t screen; T cont;
                                        :cont;
                                        s,^[\ \t]\+\(.*\)$,placeholder###\1,p;
                                        t screen; T' | sed 's,\ ,%20,g' > screen.attr

    cat nvinfo.attr | sed -ne 's,^Attribute.*\[\(gpu:[0-9a-fA-F]*\)\]:$,gpu##\1,p;
                                     t gpuattr; T;
                                     : gpuattr; n;
                                     s,^[\ \t]\+\(.*\):[\ \t]\+\(.*\)$,\1###\2,p;
                                     t gpuattr; T cont;
                                     : cont;
                                     s,^[\ \t]\+\(.*\)$,placeholder###\1,p;
                                     t gpuattr; T' | sed 's,\ ,%20,g' > gpu.attr

    # more precess onecreen attrs and  gpuattrs, split gpu attrs into
    # files for gpu number
    process_section_one "gpu"
    process_section_one "screen"

    # find the GPU we are inttrested in
    for c in $cards; do
        addr=$(echo $c | sed -ne 's,\(^.*\)::.*$,\1,p')
        cname=$(echo $c | sed -ne 's,^.*::\(.*\)$,\1,p')
        for g in $gpus; do
            gname=$(echo $g | sed -ne 's,\(^.*\)::.*$,\1,p')
            gcname=$(echo $g | sed -ne 's,^.*::\(.*\)$,\1,p')
            if [ "x"$cname = "x"$gcname ]; then
                gpu=$gname
                break
            fi
        done
    done

    echo "    \"Nvidia Settings\": {" >> $1

    # Get screen attrs and gpu attrs for $gpu
    echo -n "                          \"Screen Attributes\": [ " >> $1
    process_attributes $1 "screen" "screen"
    echo "]," >> $1

    echo -n "                          \"GPU Attributes\": [ " >> $1
    process_attributes $1 $gpu "gpu"
    echo "]" >> $1

    echo "   }," >> $1
}

collect_one() {
    card=$2
    distrbutor=$(lsb_release -i -s)
    LSPCI="lspci"
    NVSET="nvidia-settings"

    if [ $# -eq 3 ]; then
        # Maybe optirun xxx?
        LSPCI="optirun lspci"
        NVSET="optirun nvidia-settings"
    fi
	vendor=0x$($LSPCI -v -n -s $card | sed -ne 's,^[0-9]\+.*\ \([0-9a-zA-Z]*\):\([0-9a-zA-Z]*\).*$,\1,p')
	device=0x$($LSPCI -v -n -s $card | sed -ne 's,^[0-9]\+.*\ \([0-9a-zA-Z]*\):\([0-9a-zA-Z]*\).*$,\2,p')
	subvendor=0x$($LSPCI -v -n -s $card | sed -ne 's,^[\ \t]*Subsystem:\ \([0-9a-zA-Z]*\):\([0-9a-zA-Z]*\)$,\1,p')
	subdevice=0x$($LSPCI -v -n -s $card | sed -ne 's,^[\ \t]*Subsystem:\ \([0-9a-zA-Z]*\):\([0-9a-zA-Z]*\)$,\2,p')
	revision=0x$($LSPCI -v -n -s $card | grep "$card" | sed -ne 's,^.*(rev\ \+\([0-9a-fA-F]\+\)).*$,\1,p')
	driver=$($LSPCI -v -n -s $card | sed -ne 's,^[\ \t]*Kernel\ modules:\ \(.*\)$,\1,p')
    if [ $driver = "nvidia" ]; then
        driver_orig=nvidia-current
    else
        driver_orig=$driver
    fi
	drvfile=$(echo $driver_orig | xargs modinfo | sed -ne 's,^filename:\ *,,p')
	drvversion=$(echo $driver_orig | xargs modinfo | sed -ne 's,^version:\ *,,p')
	if test "x$drvversion" = "x"; then
		drvversion=$(sha256sum -b $drvfile | awk '//{print $1}')
	fi
    checksum=$(sha256sum -b $drvfile | awk '//{print $1}')

    # need to add module parameter here
	param=$(grep -ir "^options \+$driver" /etc/modprobe.d/* ./test.conf | sed 's,^.*options\ \+[0-9a-zA-Z]*\ \+,,g')

    # Add nvidia settings for nvidia card
    if [ "$driver" = "nvidia" ]; then
        collect_nvs_one $1 $card $3
    fi

    # Detecting bumblebee too?
    # one intel card + one nvidia card(specific type) or
    # two nvidia cards
    # Then the two cards are not two independent cards, so maybe
    # we should handle it separately if have to deal with it

    # GL environment variables
	ev=$(set | grep "^__GL" || :)
	case $distributor in
	Debian|Deepin)
		pkg=$(apt-file search $drvfile | grep " $drvfile" | sed -ne 's,\(^.*\):.*$,\1,p')
		;;
	Suse|Redhat)
		pkg=$(rpm -qf $drvfile | sed -ne 's,\(^.*\):.*$,\1,p')
		;;
	*)
		echo "Unknown Distribution"
		;;
	esac

	echo "    \"Vendor\": \"pci $vendor\"," >> $1
	echo "    \"Device\": \"pci $device\"," >> $1
	echo "    \"SubVendor\": \"pci $subvendor\"," >> $1
	echo "    \"SubDevice\": \"pci $subdevice\"," >> $1
    if [ "x$revision" = "x0x" ]; then
        echo "    \"Revision\": null," >> $1
    else
        echo "    \"Revision\": \"$revision\"," >> $1
    fi
	echo "    \"Driver\": \"$driver\"," >> $1
	echo "    \"Driver File\": \"$drvfile\"," >> $1
    echo "    \"sha256sum\": \"$checksum\"," >> $1
	echo "    \"Driver Version\": \"$drvversion\"," >> $1

    echo -n "    \"Module Parameters\": [" >> $1
    prev1=""
    for p in $param; do
        if [ -n "$prev1" ]; then
            echo -n ", " >> $1
        fi
        echo -n "\"$p\"" >> $1
        prev1=$p
    done
    echo "]," >> $1

    echo $ev
	echo -n "    \"Environment\": [" >> $1
    prev1=""
    for p in $ev; do
        if [ -n "$prev1" ]; then
            echo -n ", " >> $1
        fi
        echo -n "\"$p\"" >> $1
        prev1=$p
    done
    echo "]," >> $1

	echo "    \"Package\": \"${pkg:-Unknown package}\"," >> $1

	sha256sum -b $drvfile >> checksum.txt
	sort -u checksum.txt > tmp.txt
	mv tmp.txt checksum.txt
}

if [ $# -eq 2 ]; then
	prev=$2
else
	prev=""
fi

# bumblebee?
# FIXME, Maybe optirun lspci instead of lspci
bumblebee=
output=
render_card=
bbbin=$(which optirun || :)
if [ -n "$bbbin" ]; then
    num=$(lspci | awk '/VGA|3D|2D/{print $1}' | wc -l)
    LSPCI="lspci"

    if [ $num = 2 ]; then
        intel=$($LSPCI | awk '/VGA|3D|2D/{print $0}' | awk '/Intel/{print $1}')
        nvidia=$($LSPCI | awk '/VGA|3D|2D/{print $0}' | awk '/NVIDIA/{print $1}')
        # one intel card and one nvidia card
        if [ -n "$intel" ] && [ -n "$nvidia" ]; then
            bumblebee=$($LSPCI -vnn -s $nvidia | grep "\[030[02]\]" || :)
            render_card=$nvidia
        fi

        num_nvidia=$($LSPCI | awk '/VGA|3D|2D/{print $0}' | awk '/NVIDIA/{print $1}' | wc -l)
        # two nvidia cards
        if [ $num_nvidia = 2 ]; then
            for nv in $nvidia; do
                bumblebee=$($LSPCI -vnn -s $nv | grep "\[030[02]\]" || :)
                if [ -n "$bumblebee"]; then
                    render_card=$nv
                    break
                fi
            done
        fi

    fi
fi

if [ -n "$bumblebee" ]; then
    # two cards with bumblebee
    for card in $cards; do
        if [ "x"$card != "x"$render_card ]; then
            output=$card
            break
        fi
    done

    # collect info for output card
   	if [ -n "$prev" ]; then
   		echo " }," >> $1
   	fi

   	$d/header.sh $1
   	$d/videoheader.sh $1

    collect_one $1 $output
	echo "    \"DevClass\": \"Optimus\"," >> $1

    # bumblebee version information too?
	case $distributor in
	Debian)
		bbpkg=$(apt-file search $bbbin | sed -ne 's,\(^.*\):.*$,\1,p')
		if test "x$bbpkg" != "x"; then
			bbversion=$(aptitude show $bbpkg | sed -ne 's,^Version:\ ,,p')
		fi
		;;
	Suse|Redhat)
		bbpkg=$(rpm -qf $bbbin | sed -ne 's,\(^.*\):.*$,\1,p')
		if test "x$bbpkg" != "x"; then
			bbversion=$(rpm -qi $bbpkg | sed -ne 's,^Version:\ ,,p')
		fi
		;;
	*)
		echo "Unknown Distribution."
		;;
	esac
	echo "    \"Bumblebee Version\": \"$bbversion\"," >> $1
    
    # collect info for render card
    echo "    \"Render Device\": {" >> $1
    collect_one $1 $render_card "bumblebee"
    # nasty...
	echo "    \"DevClass\": \"Optimus\"" >> $1
    echo "                       }," >> $1

   	$LSPCI -v -s $output
    $LSPCI -v -s $render_card
    answer=""
   	while test "x$answer" = "x" -o "x$tmp" != "x" || 
   		[ $answer -lt -100 -o  $answer -gt 100 ]; do
   		read -p "Please score the two graphic card with bumblebee.(rang: -100 - 100, -100 totally not work, 100 fully functional)" answer
   		tmp=$(echo $answer | sed 's,^-,,g' | sed 's,[0-9]\+,,g')
   		if [ "x$tmp" != "x" ]; then
   			echo "Not a number, Please enter a number."
   		elif [ $answer -lt -100 -o $answer -gt 100 ]; then
   			echo "Please enter a number between -100 - 100"
   		fi
   	done

   	echo "    \"Score\": \"$answer\"" >> $1
else
    for card in $cards; do
    	if [ -n "$prev" ]; then
    		echo " }," >> $1
    	fi

    	lspci -v -s $card
        answer=""
    	while test "x$answer" = "x" -o "x$tmp" != "x" || 
    		[ $answer -lt -100 -o  $answer -gt 100 ]; do
    		read -p "Please score the driver.(rang: -100 - 100, -100 totally not work, 100 fully functional)" answer
    		tmp=$(echo $answer | sed 's,^-,,g' | sed 's,[0-9]\+,,g')
    		if [ "x$tmp" != "x" ]; then
    			echo "Not a number, Please enter a number."
    		elif [ $answer -lt -100 -o $answer -gt 100 ]; then
    			echo "Please enter a number between -100 - 100"
    		fi
    	done

    	$d/header.sh $1
    	$d/videoheader.sh $1

	    echo "    \"DevClass\": \"gfxcard\"," >> $1
        collect_one $1 $card
    	echo "    \"Score\": \"$answer\"" >> $1

    	prev=$card
    done
fi

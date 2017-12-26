#!/bin/bash
######################################################################
## SparseSectorsExtr.sh version 0.86 -- public 20171225
## (C) Traie Ward
## Started 20151116
## Up to W.E. 20151119 -- Pulled out enough debug messages and pauses
##                   to make the script actually usable and
##                   rearranged and changed the remaining ones a
##                   little and brought back a few old pause prompts
##                   as non-pausing messages. Changed the debug form
##                   output filename prefix to the non-debug form.
##                   This is the version I'm about to use for the job
##                   I designed it for.
##   version 0.85 -- Rearranged and edited and clarified prior
##                   version history. Toned down the debug messages
##                   and pauses considerably. Wrote in filesize check
##                   on tempfilea to detect end of infile (or other
##                   error) and added correct boundary case handling
##                   in that case. Corrected variable reference
##                   errors in the printing of the final stats.
##                   Corrected the handling of the first read
##                   non-null sector in the case that it is the start
##                   of a longer segment!!! Yikes! Added a good deal
##                   of section heading comments. Knows its own
##                   version number now. Changed the block device
##                   test section to recognize that lsblk outputs
##                   negative results to stderr not stdout and
##                   refactored that section accordingly. Wrote in
##                   file size check for ordinary file infile and
##                   wrote in an adjustment on lastsector if that
##                   file size implies a smaller last sector number.
##                   And last, final essential change: Corrected the
##                   code that corrects lastsector based on block
##                   device or ordinary file size so that it respects
##                   lastsector's zero-indexed-ness.
##                   It all now works.
##   version 0.8  -- Changed uses of maxsectors, maxfiles, sumSegs,
##                   and segStart to use and recognize and maintain
##                   formatting to appropriate fixed lengths, and
##                   corrected the use of echo in the section that
##                   makes a Null512B when none is found so that it
##                   could actually work if tried.
##   version 0.75 -- Working draft (after correcting many, many small
##                   errors, from having been an almost working
##                   draft in 0.7), correcting the status option in
##                   the invocations of dd, resudoing the invocations
##                   of dd (making them active), muting the stderr
##                   output of dd, and invoking date at the beginning
##                   and end of the script (for while I'm developing
##                   it).
##   version 0.7  -- First draft, fourth revision -- correcting the
##                   loop logic on the first while loop (to respect
##                   stopat), and changing how lsblkinfile is broken
##                   up into an array so that it does actually get
##                   divided into an array! And other small changes
##                   to make it work.
##   version 0.65 -- First draft, third revision -- Correcting
##                   variable reference syntax in test statements,
##                   spacing the test brakets properly, closing the
##                   spaces after the brakets and before the
##                   semicolons, changed (extended) the output
##                   filename format, loaded up on debug break
##                   points, fixed the backwards logic of selecting
##                   the temp directory, corrected two uses of the
##                   10# base forcer, and changed the substring
##                   method to something more direct.
##   version 0.6  -- First draft, second revision (in order to even
##                   run!) -- It knows its own name properly now, and
##                   is flexible about the location of Null512B, and
##                   will make its own temporary Null512B if it can't
##                   find one, and it is set move to the target
##                   directory to run in and then to return to the
##                   calling directory on exit. Moreover, for block
##                   devices, it now sanity checks lastsector for
##                   itself and restricts it downward accordingly.
##   version 0.5  -- First complete draft, ready for testing
######################################################################
## Outstanding issues or work
##   Check if the field width of stopat is best adjusted the way it
##     is, no matter what the length of lastsector is, etc
######################################################################

date

echo "Sparse Sectors Extractor version 0.86 [as of W.E. 20151119]"

helpstring_="Usage: ./SparseSectorsExtrV0x86.sh [target directory] [in block device] [start sector] [stop sector] [last sector (for safety)] [max sectors to copy] [max files to produce]"

a1_=$1
a1_c=${#a1_}
if [ ${a1_c} -eq 0 ]; then
    echo ${helpstring_}
    exit 0
else
    a1_1=`echo ${a1_} | cut -c1-1`
    if [ ${a1_1} = "-" ]; then
        echo ${helpstring_}
        exit 0
    fi
fi

read -n1 -r -p "Press any key to continue..." key   # Debug pause

#DT1=`date '+%Y%m%d%H%M%S%N'`
#DT2=`echo ${DT1} | cut -c1-14`
prefix="SparseDataPS"   #"SparseDataPSdebug"${DT2}   # "debug" and ${DT2} in prefix temporary, to prevent later confusion
targetdirectory=$1
infile=$2
DT1=`date '+%Y%m%d%H%M%S%N'`
DT2=`echo ${DT1} | cut -c1-14`
if [ -d "$TMPDIR" ]; then
    thetempdir=$TMPDIR
elif [ -d /tmp ]; then
    thetempdir="/tmp"
else
    thetempdir="."
fi
if [ ${#thetempdir} -eq 0 ]; then
    thetempdir="/tmp"
fi
tempfilea=${thetempdir}/tmpa${DT2}
tempfileb=${thetempdir}/tmpb${DT2}
tempfiledd=${thetempdir}/tmpdd${DT2}
lsblkinfileerrfile=${thetempdir}/lsblkinfileerrfile${DT2}
blankname=Null512B
counter=$3
stopat=$4
lastsector=$5
maxsectors=$6
maxfiles=$7
numfiles=0

### PUT CHECKS FOR NULL STRINGS HERE AND PROVIDE DEFAULT VALUES [Thought: 20151118 108PME]

calldir=${PWD}
scriptdir=$(dirname $0)

if [ -d $targetdirectory ]; then
  tgd=$targetdirectory
else
  tgd=$calldir
fi

tryblankpathname1=${tgd}/${blankname}
tryblankpathname2=${calldir}/${blankname}
if [ -f ${tryblankpathname1} ]; then
    blank=${tryblankpathname1}
elif [ -f ${tryblankpathname2} ]; then
    blank=${tryblankpathname2}
else
    echo -ne "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" > ${thetempdir}/SixteenNulls${DT2}
    cat ${thetempdir}/SixteenNulls${DT2} > ${thetempdir}/SixtyFourNulls${DT2}
    cat ${thetempdir}/SixteenNulls${DT2} >> ${thetempdir}/SixtyFourNulls${DT2}
    cat ${thetempdir}/SixteenNulls${DT2} >> ${thetempdir}/SixtyFourNulls${DT2}
    cat ${thetempdir}/SixteenNulls${DT2} >> ${thetempdir}/SixtyFourNulls${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} > ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    cat ${thetempdir}/SixtyFourNulls${DT2} >> ${thetempdir}/Null512B${DT2}
    blank=${thetempdir}/Null512B${DT2}
fi

### ECHO ALL VARIABLES SO FAR
echo $prefix   # Debug
echo "target directory" $targetdirectory "tgd" $tgd   # Debug
#read -n1 -r -p "..." key   # Debug pause
#if [ "$tgd" = "$targetdirectory" ]; then
#    echo "target directory " $targetdirectory
#else
#    echo "specified target directory " $targetdirectory
#    echo "Target directory not found. Using: " $tgd
#fi
echo "calling directory" $calldir "script directory" $scriptdir "thetempdir" $thetempdir
echo "infile" $infile
echo $tempfilea " " $tempfileb " " $tempfiledd
echo "blank" $blank "counter" $counter
echo "stopat" $stopat "lastsector" $lastsector "maxsectors" $maxsectors "maxfiles" $maxfiles "numfiles" $numfiles

read -n1 -r -p "Press any key to continue..." key   # Debug pause

if [ $((10#$maxsectors)) -lt 1 ]; then
    exit 0
fi
if [ $((10#$maxfiles)) -lt 1 ]; then
    exit 0
fi

if [ -e $infile ]; then
    infileexists=1
else
    echo "Infile not found:" $infile
    exit 0
fi

read -n1 -r -p "Infile exists..." key   # Debug pause

##### This section attempts to determine if infile is a block device and if so what its block
#####   size and number of blocks is, and if it can tell, it sanity checks and adjusts lastblock
isnotablockdevice=0
isablockdevice=0    # If no test comes out positive (if both remain zero), remain agnostic and just try it
lsblkinfile=`lsblk -b -l ${infile} -n --output NAME,SIZE,PHY-SEC,LOG-SEC 2> $lsblkinfileerrfile`
lsblkinfileerr=`cat $lsblkinfileerrfile`
echo "lsblkinfile" $lsblkinfile   # Debug
echo "lsblkinfileerr" $lsblkinfileerr   # Debug
lsblkinfile_c=${#lsblkinfile}
lsblkinfileerr_c=${#lsblkinfileerr}
if [ ${lsblkinfile_c} -gt 0 ]; then
    arr=(`echo $lsblkinfile | tr " " "\n"`)
    #getaa=${lsblkinfile//"\n"/" "}
    
    cmpinfilename=/dev/${arr[0]}
    arr0_c=${#arr[0]}
    echo -n "cmpinfilename" $cmpinfilename "... "   # Debug
    #read -n1 -r -p " ... " key   # Debug pause
    
    if [[ $cmpinfilename = $infile ]]; then
        isablockdevice=1
        echo "isablockdevice=1"   # Debug
    else
        isablockdevice=0 # Do not know for sure
    fi
fi
if [ ${lsblkinfileerr_c} -gt 18 ]; then
    #set -x   # Debug
    #lsblkmsg=`echo $lsblkinfile | cut -c$(($lsblkinfile_c - 17))-$(($lsblkinfile_c))`
    lsblkmsg=${lsblkinfileerr:$(($lsblkinfileerr_c - 18)):18}
    #set +x   # Debug
    echo "lsblkmsg" $lsblkmsg   # Debug
    #read -n1 -r -p " " key   # Debug pause   # This one complained when it didn't have a prompt and prompt text
    notablockdevicemsg="not a block device"
    if [[ $lsblkmsg = $notablockdevicemsg ]]; then
        isnotablockdevice=1
        echo "isnotablockdevice=1"   # Debug
    else
        isnotablockdevice=0 # Do not know for sure
    fi
fi
if [ $isnotablockdevice -eq 0 ] && [ $isablockdevice=0 ]; then
    echo "Can't determine infile to be either a block device or not a block device."   # Debug
fi

echo "Done testing whether infile is a block device..."   # Debug
#read -n1 -r -p "Done testing whether infile is a block device..." key   # Debug pause

if [ $isablockdevice -eq 1 ]; then
    infilesize=${arr[1]}
    infilesectorsize=${arr[3]}
    if [ $infilesectorsize -ne 0 ]; then
        determinedblocks=$(($infilesize / $infilesectorsize))
        if [ $lastsector -eq 0 ]; then
            lastsector=$(($determinedblocks - 1))
            echo Number of sectors in block device infile determined to be $determinedblocks
        elif [ $determinedblocks -le $lastsector ]; then
            lastsector=$(($determinedblocks - 1))
            echo Number of sectors in block device infile determined to be $determinedblocks
        fi
    else
        echo infilesectorsize is zero!
        exit 1
    fi
fi

if [ $isnotablockdevice -eq 1 ]; then
    infilesize=$(stat -c '%s' $infile)
    infilesectorsize=512
    determinedblocks=$(($infilesize / $infilesectorsize))
    if [ $(($determinedblocks * $infilesectorsize)) -lt $infilesize ]; then
        determinedblocks=$(($determinedblocks + 1))
    fi
    if [ $lastsector -eq 0 ]; then
        lastsector=$(($determinedblocks - 1))
        echo Number of sectors in file infile determined to be $determinedblocks
    elif [ $determinedblocks -le $lastsector ]; then
        lastsector=$(($determinedblocks - 1))
        echo Number of sectors in file infile determined to be $determinedblocks
    fi
fi

echo -n "lastsector" $lastsector "determinedblocks" $determinedblocks " "   # Debug
echo "infilesize" $infilesize "infilesectorsize" $infilesectorsize   # Debug
echo "Done with any block size computation..."   # Debug
#read -n1 -r -p "Done with any block size computation..." key   # Debug pause

######## Set up the fixed number field lengths based on the input arguments
counterlength=${#counter}
prtstr="%0"$((10#$counterlength))"d"

stopatlength=${#stopat}
if [ $counterlength -gt $stopatlength ]; then
    stopatlength=$counterlength
fi
prtstrstopat="%0"$((10#$stopatlength))"d"
stopat=`printf $prtstrstopat $((10#$stopat))`

maxsectorslength=${#maxsectors}
prtstrmaxsectors="%0"$((10#$maxsectorslength))"d"
maxsectors=`printf $prtstrmaxsectors $((10#$maxsectors))`

maxfileslength=${#maxfiles}
prtstrmaxfiles="%0"$((10#$maxfileslength))"d"
maxfiles=`printf $prtstrmaxfiles $((10#$maxfiles))`

echo -n "stopat" $stopat "stopatlength" $stopatlength " "   # Debug
echo -n "maxsectors" $maxsectors "maxsectorslength" $maxsectorslength " "   # Debug
echo "maxfiles" $maxfiles "maxfileslength" $maxfileslength   # Debug
echo "counter, stopat, maxsectors, and maxfiles values formatted..."   # Debug
#read -n1 -r -p "counter, stopat, maxsectors, and maxfiles values formatted..." key   # Debug pause

# cd $tgd # Maybe change to the target directory to work # Not doing this now

read -n1 -r -p "Ready to begin. (Last pause, last chance to stop!) Press any key to proceed..." key

######################################## THIS BIG IF-ELSE-FI IS THE CONDITION CHECK BEFORE FIRST READ AND THE FIRST READ
if [ $((10#$counter)) -le $lastsector ] && [ $((10#$counter)) -le $((10#$stopat)) ]; then
    ##### THE FIRST READ
    echo "dd if=$infile of=$tempfilea bs=512 skip=$((10#$counter)) count=1 conv=noerror status=noxfer 2> $tempfiledd"
    #set -x
    sudo dd if=$infile of=$tempfilea bs=512 skip=$((10#$counter)) count=1 conv=noerror status=noxfer 2> $tempfiledd
    #set +x
    filesizetmpa=$(stat -c '%s' $tempfilea)
    if [ "$filesizetmpa" -eq 0 ]; then
        echo "End of file reached (or other reading error) and no data found. Done."
        date
        # cd $calldir
        exit 0
    fi
    cr_=`diff -q $tempfilea $blank`
    r_=${#cr_}
else
    if [ $((10#$counter)) -le $lastsector ]; then
        echo "counter ("${counter}") already past lastsector ("${lastsector}"). Done."
    elif [ $((10#$counter)) -le $((10#$stopat)) ]; then
        echo "counter ("${counter}") already past stopat ("${stopat}"). Done."
    fi
    # cd $calldir
    date
    exit 0
fi
######################################## THIS LOOP READS FOR THE FIRST NON-NULL BLOCK IF THE FIRST READ WASN'T IT
while [ ${r_} -eq 0 ] && [ $((10#$counter)) -lt $lastsector ] && [ $((10#$counter)) -lt $((10#$stopat)) ]; do
    counter=`printf $prtstr $((10#$counter + 1))`
    #echo "dd if=$infile of=$tempfilea bs=512 skip=$((10#$counter)) count=1 conv=noerror status=noxfer 2> $tempfiledd"
    # set -x
    sudo dd if=$infile of=$tempfilea bs=512 skip=$((10#$counter)) count=1 conv=noerror status=noxfer 2> $tempfiledd
    # set +x
    filesizetmpa=$(stat -c '%s' $tempfilea)
    if [ "$filesizetmpa" -eq 0 ]; then
        echo "End of file reached (or other reading error) and no data found. Done."
        date
        # cd $calldir
        exit 0
    fi
    cr_=`diff -q $tempfilea $blank`
    r_=${#cr_}
done

echo -n "r_" ${r_} "counter" $counter " "   # Debug
echo "Done with first while loop..."
#read -n1 -r -p "Done with first while loop..." key   # Debug pause

#################### IF WE REACHED AN END BOUNDARY, WRAP UP AND BE DONE
if [ $((10#$counter)) -eq $lastsector ] || [ $((10#$counter)) -eq $((10#$stopat)) ]; then
    if [ ${r_} -eq 0 ]; then
        echo The whole range is null.
        # cd $calldir
        date
        exit 0
    else
        wideoneseg=`printf $prtstrmaxfiles 1`
        flnm=${prefix}-${wideoneseg}-${counter}-1
        echo "cat $tempfilea > ${tgd}/${flnm}"
        #set -x
        #cp $tempfilea ./${flnm}
        cat $tempfilea > ${tgd}/${flnm}
        #set +x
        echo 1 sector in 1 segment.
        # cd $calldir
        date
        exit 0
    fi
fi

#################### IF THE FIRST LOOP GAVE US NON-NULLDATA TO START WITH THEN 
if [ ${r_} -ne 0 ]; then
    ##### WE'RE DONE IF THE USER ONLY ASKED FOR ONE SECTOR
    if [ $((10#$maxsectors)) -eq 1 ]; then
        wideoneseg=`printf $prtstrmaxfiles 1`
        flnm=${prefix}-${wideoneseg}-${counter}-1
        echo "cat $tempfilea > ${tgd}/${flnm}"
        #set -x
        #cp $tempfilea ./${flnm}
        cat $tempfilea > ${tgd}/${flnm}
        #set +x
        echo 1 sector in 1 segment.
        # cd $calldir
        date
        exit 0
    else
        ##### Now process $counter as the beginning of a new segment
        lastN=$((10#$counter))
        segStart=`printf $prtstrstopat $((10#$counter))`
        segLen=1
        sumSectors=1
        sumSegs=`printf $prtstrmaxfiles 1`
        
        #echo "New" $sumSegs " "   # Debug
        
        echo "cat $tempfilea > $tempfileb"
        #set -x
        #cp $tempfilea $tempfileb
        cat $tempfilea > $tempfileb
        #set +x
    fi
else
    # Actually, this should never get executed. It would mean that
    echo Something is wrong, it seems.
    lastN=-2
    segStart=-2
    segLen=0
    sumSectors=0
    sumSegs=`printf $prtstrmaxfiles 0`
    # cd $calldir
    date
    exit 1
fi

echo "lastN" $lastN "segStart" $segStart "segLen" $segLen "sumSectors" $sumSectors "sumSegs" $sumSegs   # Debug
#read -n1 -r -p "Yet more ready..." key   # Debug pause

#################### INCREMENT AHEAD OF MAIN LOOP (WHICH INCREMENTS AT THE END) (THEN BOUNDARY CHECK)
counter=`printf $prtstr $((10#$counter + 1))`
if [ $((10#$counter)) -le $((10#$stopat)) ]; then
    done=0
else
    done=1
fi
if [ $((10#$counter)) -gt $lastsector ]; then
    done=1
fi
echo -n "counter" $counter "done" $done " "   # Debug
echo "About to start main loop..."
#read -n1 -r -p "About to start main loop..." key   # Debug pause
while [ $done -eq 0 ]; do     ############################################################ THE MAIN LOOP
    
    ##### THE MAIN READ
    #echo "dd if=$infile of=$tempfilea bs=512 skip=$((10#$counter)) count=1 conv=noerror status=noxfer 2> $tempfiledd"
    #set -x
    sudo dd if=$infile of=$tempfilea bs=512 skip=$((10#$counter)) count=1 conv=noerror status=noxfer 2> $tempfiledd
    #set +x
    
    filesizetmpa=$(stat -c '%s' $tempfilea) ########## CHECK IF READ GOT ANYTHING AT ALL
    if [ "$filesizetmpa" -eq 0 ]; then          ########## IF NOT, THEN FINISH WITH ANY OPEN SEGMENT
        echo "End of file reached (or other reading error)."
        if [ ${r_} -ne 0 ]; then # NOTE: At this point, this indicates the PREVIOUS, last block was non-null
            counter=`printf $prtstr $((10#$counter - 1))` # Decrement $counter to count only the last block
            flnm=${prefix}-${sumSegs}-${segStart}-${segLen}
            echo "cat $tempfileb > ${tgd}/${flnm}"
            #set -x
            #cp $tempfileb ./${flnm}
            cat $tempfileb > ${tgd}/${flnm}
            #set +x
            numfiles=$(($numfiles + 1))
            echo "Fin" $numfiles " "   # Debug
            if [ $numfiles -ne $((10#$sumSegs)) ]; then
                echo "Number of files output ("{$numfiles}") doesn't equal the number of segments ("{$sumSegs}")!"
                # cd $calldir
                date
                exit 1
            fi
        fi
    else
        cr_=`diff -q $tempfilea $blank`
        r_=${#cr_}
        
        #echo -n $counter " " ${r_}   # Debug
        #read -n1 -r key     # A pause for debug tracing and being able to stop it
        
        if [ ${r_} -ne 0 ]; then
            if [ $((10#$counter)) -eq $(($lastN + 1)) ]; then
                lastN=$((10#$counter))
                segLen=$(($segLen + 1))
                sumSectors=$(($sumSectors + 1))
                
                #echo "cat $tempfilea >> $tempfileb"
                #set -x
                cat $tempfilea >> $tempfileb
                #set +x
            else
                ##### Now process the new $counter as the beginning of a new segment
                lastN=$((10#$counter))
                segStart=`printf $prtstrstopat $((10#$counter))`
                segLen=1
                sumSectors=$(($sumSectors + 1))
                sumSegs=`printf $prtstrmaxfiles $((10#$sumSegs + 1))`
                
                #echo "New" $sumSegs " "   # Debug
                
                #echo "cat $tempfilea > $tempfileb"
                #set -x
                cat $tempfilea > $tempfileb
                #set +x
            fi
        else
            if [ $lastN -eq $((10#$counter - 1)) ]; then   # This little section is for when the last block was the last of a
                flnm=${prefix}-${sumSegs}-${segStart}-${segLen}
                echo "cat $tempfileb > ${tgd}/${flnm}"
                #set -x
                #cp $tempfileb ./${flnm}
                cat $tempfileb > ${tgd}/${flnm}
                #set +x
                numfiles=$(($numfiles + 1))
                #echo "Fin" $numfiles " "   # Debug
                if [ $numfiles -ne $((10#$sumSegs)) ]; then
                    echo "Number of files output ("{$numfiles}") doesn't equal the number of segments ("{$sumSegs}")!"
                    # cd $calldir
                    date
                    exit 1
                fi
            fi
        fi # End of else of if [ ${r_} -ne 0 ]
    fi # End of else of if [ "$filesizetmpa" -eq 0 ]
    
    ##### THE MAIN INCREMENTING, THEN A BATTERY OF BOUNDARY CHECKS
    counter=`printf $prtstr $((10#$counter + 1))`
    if [ $((10#$counter)) -le $((10#$stopat)) ]; then
        done=0
    else
        done=1
    fi
    if [ "$filesizetmpa" -eq 0 ]; then
        done=1
    fi
    if [ $((10#$counter)) -gt $lastsector ]; then
        done=1
    fi
    
    if [ $((10#$sumSectors)) -ge $((10#$maxsectors)) ]; then
        done=1
    fi
    if [ $((10#$numfiles)) -ge $((10#$maxfiles)) ]; then
        done=1
    fi
done #################### END OF THE MAIN LOOP

echo "Out of main loop..."
#read -n1 -r -p "Out of main loop..." key   # Debug pause

#################### POST-LOOP WORK: IF THE LAST SEGMENT WAS IN PROGRESS, FINISH IT
#if [ $lastN -eq $((10#$counter - 1)) ]; then# No, going to do this a different way
echo "numfiles" $numfiles "\$((10#\$sumSegs))" $((10#$sumSegs))
if [ $numfiles -lt $((10#$sumSegs)) ]; then
    echo "In post-loop work..."   # Debug
    if [ "$filesizetmpa" -eq 0 ]; then # This conditional for debug purposes
        echo There\'s something wrong with boundary conditions after null file!
        echo "numfiles" $numfiles "sumSegs" $sumSegs
        # cd $calldir
        date
        exit 1
    fi
    # Formulate the output filename
    flnm=${prefix}-${sumSegs}-${segStart}-${segLen}
    # Output the file
    echo "cat $tempfileb > ${tgd}/${flnm}"
    #set -x
    #cp $tempfileb ./${flnm}
    cat $tempfileb > ${tgd}/${flnm}
    #set +x
    # Update the stats
    numfiles=$(($numfiles + 1))
    if [ $numfiles -ne $((10#$sumSegs)) ]; then
        echo "Number of files output ("{$numfiles}") doesn't equal the number of segments ("{$sumSegs}")!"
        # cd $calldir
        date
        exit 1
    fi
fi

# Print the stats
if [ $sumSectors -eq 1 ]; then
    sectors_="sector"
else
    sectors_="sectors"
fi
if [ $((10#$sumSegs)) -eq 1 ]; then
    segments_="segment"
else
    segments_="segments"
fi
echo $sumSectors ${sectors_} "in" $sumSegs ${segments_}"."
echo "counter" $counter
echo $tempfilea $tempfileb $tempfiledd
echo "blank stopat lastsector maxsectors maxfiles numfiles"
echo $blank $stopat $lastsector $maxsectors $maxfiles $numfiles

# cd $calldir
date
exit 0

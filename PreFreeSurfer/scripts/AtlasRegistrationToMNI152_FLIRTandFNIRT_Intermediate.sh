#!/bin/bash 
set -x

export OMP_NUM_THREADS=1
export PATH=`echo $PATH | sed 's|freesurfer/|freesurfer53/|g'`

# Requirements for this script
#  installed versions of: FSL5.0.1+
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for non-linearly registering T1w and T2w to MNI space, including intermediate registration to a study template (T1w and T2w must already be registered together)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "                --t1=<t1w image>"
  echo "                --t1rest=<bias corrected t1w image>"
  echo "                --t1restbrain=<bias corrected, brain extracted t1w image>"
  echo "                --t2=<t2w image>"
  echo "	 	        --t2rest=<bias corrected t2w image>"
  echo "                --t2restbrain=<bias corrected, brain extracted t2w image>"
  echo "                --studytemplate=<study template t1w image>"
  echo "                --studytemplatebrain=<study template brain extracted t1w image>"
  echo "                --studytemplatebrainmask=<study template binary brain mask>"
  echo "                --ref=<reference image>"
  echo "                --refbrain=<reference brain image>"
  echo "                --refmask=<reference brain mask>"
  echo "                [--ref2mm=<reference 2mm image>]"
  echo "                [--ref2mmmask=<reference 2mm brain mask>]"
  echo "                --intowarp=<intermediate (subject to study template) output warp>"
  echo "                --intoinvwarp=<intermediate output inverse warp>"
  echo "                --int2refowarp=<intermediate to reference output warp>"
  echo "                --int2foinvwarp=<intermediate to reference output inverse warp>"
  echo "                --owarp=<output warp>"
  echo "                --oinvwarp=<output inverse warp>"
  echo "                --ot1=<output t1w to MNI>"
  echo "                --ot1rest=<output bias corrected t1w to MNI>"
  echo "                --ot1restbrain=<output bias corrected, brain extracted t1w to MNI>"
  echo "                --ot2=<output t2w to MNI>"
  echo "		        --ot2rest=<output bias corrected t2w to MNI>"
  echo "                --ot2restbrain=<output bias corrected, brain extracted t2w to MNI>"
  echo "                [--fnirtconfig=<FNIRT configuration file>]"
  echo "                --useT2=<False if T2 is poor or not available. Default True>"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD):  xfms/acpc2StudyTemplate.mat  
#                    xfms/${T1wRestoreBrainBasename}_to_StudyTemplate  
#                    xfms/StudyTemplateIntensityModulatedT1.nii.gz  
#                    xfms/StudyTemplateNonlinearRegJacobians.nii.gz   xfms/StudyTemplateReg.nii.gz  
#                    xfms/StudyTemplateNonlinearReg.txt  xfms/StudyTemplateNonlinearIntensities.nii.gz  
#                    xfms/StudyTemplateNonlinearReg.nii.gz 
#
#                    xfms/StudyTemplate2MNILinear.mat  
#                    xfms/StudyTemplate_to_MNILinear  
#                    xfms/ReferenceIntensityModulatedT1.nii.gz  
#                    xfms/ReferenceNonlinearRegJacobians.nii.gz xfms/ReferenceReg.nii.gz  
#                    xfms/ReferenceNonlinearReg.txt  xfms/ReferenceNonlinearIntensities.nii.gz  
#                    xfms/ReferenceNonlinearReg.nii.gz 
#
# Outputs (not in $WD): ${OutputTransform} ${OutputInvTransform}   
#                       ${OutputT1wImage} ${OutputT1wImageRestore}  
#                       ${OutputT1wImageRestoreBrain}
#                       ${OutputT2wImage}  ${OutputT2wImageRestore}  
#                       ${OutputT2wImageRestoreBrain}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 24 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wRestore=`getopt1 "--t1rest" $@`  # "$3"
T1wRestoreBrain=`getopt1 "--t1restbrain" $@`  # "$4"
T2wImage=`getopt1 "--t2" $@`  # "$5"
T2wRestore=`getopt1 "--t2rest" $@`  # "$6"
T2wRestoreBrain=`getopt1 "--t2restbrain" $@`  # "$7"
StudyTemplate=`getopt1 "--studytemplate" $@`# "${8}"
StudyTemplateBrain=`getopt1 "--studytemplatebrain" $@` # "${9}"
StudyTemplateBrainMask=`getopt1 "--studytemplatebrainmask" $@` # "${10}"
Reference=`getopt1 "--ref" $@`  # "$11"
ReferenceBrain=`getopt1 "--refbrain" $@`  # "$12"
ReferenceMask=`getopt1 "--refmask" $@`  # "${13}"
Reference2mm=`getopt1 "--ref2mm" $@`  # "${14}"
Reference2mmMask=`getopt1 "--ref2mmmask" $@`  # "${15}"
IntOutputTransform=`getopt1 "--intowarp" $@`  # "${16}"
IntOutputInvTransform=`getopt1 "--intoinvwarp" $@`  # "${17}"
Int2RefOutputTransform=`getopt1 "--int2refowarp" $@`  # "${18}"
Int2RefOutputInvTransform=`getopt1 "--int2refoinvwarp" $@`  # "${19}"
OutputTransform=`getopt1 "--owarp" $@`  # "${20}"
OutputInvTransform=`getopt1 "--oinvwarp" $@`  # "${21}"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${22}"
OutputT1wImageRestore=`getopt1 "--ot1rest" $@`  # "${23}"
OutputT1wImageRestoreBrain=`getopt1 "--ot1restbrain" $@`  # "${24}"
OutputT2wImage=`getopt1 "--ot2" $@`  # "${25}"
OutputT2wImageRestore=`getopt1 "--ot2rest" $@`  # "${26}"
OutputT2wImageRestoreBrain=`getopt1 "--ot2restbrain" $@`  # "${27}"
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${28}"
useT2=`getopt1 "--useT2" $@` # "${29}"

#ERIC: # default parameters
#ERIC: WD=`defaultopt $WD .`
#ERIC: Reference2mm=`defaultopt $Reference2mm ${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz`
#ERIC: Reference2mmMask=`defaultopt $Reference2mmMask ${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`
#ERIC: FNIRTConfig=`defaultopt $FNIRTConfig ${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf`


T1wRestoreBasename=`remove_ext $T1wRestore`;
T1wRestoreBasename=`basename $T1wRestoreBasename`;
T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;

echo " "
echo " START: AtlasRegistration to MNI152 (with intermediate registration to study template)"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

########################################## DO WORK ########################################## 

# Linear then non-linear registration from subject -> study template
${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${T1wRestoreBrain} -ref ${StudyTemplateBrain} -omat ${WD}/xfms/acpc2StudyTemplate.mat -out ${WD}/xfms/${T1wRestoreBrainBasename}_to_StudyTemplate

${FSLDIR}/bin/fnirt --in=${T1wRestore} --ref=${StudyTemplateBrain} --aff=${WD}/xfms/acpc2StudyTemplate.mat --refmask=${StudyTemplateBrainMask} --fout=${IntOutputTransform} --jout=${WD}/xfms/StudyTemplateNonlinearRegJacobians.nii.gz --refout=${WD}/xfms/StudyTemplateIntensityModulatedT1.nii.gz --iout=${WD}/xfms/StudyTemplateReg.nii.gz --logout=${WD}/xfms/T1w2StudyTemplateNonlinearReg.txt --intout=${WD}/xfms/StudyTemplateNonlinearIntensities.nii.gz --cout=${WD}/xfms/StudyTemplateNonlinearReg.nii.gz --config=${FNIRTConfig}

# Input and reference spaces are the same (acpc-aligned)
${FSLDIR}/bin/invwarp -w ${IntOutputTransform} -o ${IntOutputInvTransform} -r ${StudyTemplate}

# Linear then non-linear registration from study template-registered T1w -> "MNI" reference 
${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${WD}/xfms/${T1wRestoreBrainBasename}_to_StudyTemplate -ref ${ReferenceBrain} -omat ${WD}/xfms/StudyTemplate2MNILinear.mat -out ${WD}/xfms/StudyTemplate_to_MNILinear

${FSLDIR}/bin/fnirt --in=${WD}/xfms/${T1wRestoreBrainBasename}_to_StudyTemplate --ref=${Reference} --aff=${WD}/xfms/StudyTemplate2MNILinear.mat --refmask=${ReferenceMask} --fout=${Int2RefOutputTransform} --jout=${WD}/xfms/StudyTemplate2MNINonlinearRegJacobians.nii.gz --refout=${WD}/xfms/StudyTemplate2MNIIntensityModulatedT1.nii.gz --iout=${WD}/xfms/StudyTemplate2MNIReg.nii.gz --logout=${WD}/xfms/StudyTemplate2MNINonlinearReg.txt --intout=${WD}/xfms/StudyTemplate2MNINonlinearIntensities.nii.gz --cout=${WD}/xfms/StudyTemplate2MNINonlinearReg.nii.gz --config=${FNIRTConfig}

# Input and reference spaces are the same (acpc-aligned)
${FSLDIR}/bin/invwarp -w ${Int2RefOutputTransform} -o ${Int2RefOutputInvTransform} -r ${Reference}

# Combine forward warps
${FSLDIR}/bin/convertwarp --warp1=${IntOutputTransform} --warp2=${Int2RefOutputTransform} --ref=${Reference} --out=${OutputTransform}

# Make combined inverse warp
${FSLDIR}/bin/invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${Reference}

# T1w set of warped outputs (brain/whole-head + restored/orig)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImage}
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestore}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestoreBrain}
${FSLDIR}/bin/fslmaths ${OutputT1wImageRestore} -mas ${OutputT1wImageRestoreBrain} ${OutputT1wImageRestoreBrain}

if $useT2; then
# T2w set of warped outputs (brain/whole-head + restored/orig)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImage}
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestore}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T2wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestoreBrain}
${FSLDIR}/bin/fslmaths ${OutputT2wImageRestore} -mas ${OutputT2wImageRestoreBrain} ${OutputT2wImageRestoreBrain}
fi
echo " "
echo " END: AtlasRegistration to MNI152 (with intermediate registration to study template)"
echo " END: `date`" >> $WD/xfms/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
echo "cd `pwd`" >> $WD/xfms/qa.txt
echo "# Check quality of alignment with MNI image" >> $WD/xfms/qa.txt
echo "fslview ${Reference} ${OutputT1wImageRestore}" >> $WD/xfms/qa.txt
echo "fslview ${Reference} ${OutputT2wImageRestore}" >> $WD/xfms/qa.txt

##############################################################################################

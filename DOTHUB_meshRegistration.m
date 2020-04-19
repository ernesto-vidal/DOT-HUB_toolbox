function [rmap, rmapFileName] = DOTHUB_meshRegistration(SD_3DFullFileName,origMeshFullFileName)

% This function takes the landmarks and source and detector locations for an individual
% and registers the selected mesh (atlas or subject specific) into the native space of the
% individual. It uses the landmarks to transform between the two spaces.
% We hope to expand registration options, but at present this is performed
% with a simple Affine transformation.

%The result is saved to the same location as the SD_3DFileName

% ####################### INPUTS ##########################################

% SD_3DFullFileName     :   The full path of the 3D .SD file, which should
%                           itself be named after the posData.csv from which is
%                           was derived

% origMeshFullFileName  :   The full path to the original mesh .mat file, which contains 
%                           the following variables:
    
                     % headVolumeMesh    :   The multi-layer volume mesh structure, Contains
                     %                       fields node, face, elem.

                     % gmSurfaceMesh     :   The gm surface mesh structure, Contains fields:
                     %                       node, face.

                     % scalpSurfaceMesh  :   The scalp surface mesh structure, contains fields:
                     %                       node, face.

                     % landmarks         :   5 x 3 matrix of the cranial landmark coordinates on
                     %                       the mesh surface. Nz, Iz, Ar, Al, Cz.

                     % vol2gm            :   (Optional) The sparse matrix mapping from head volume mesh
                     %                       space to GM surface mesh space. Calculated if not parsed

% ####################### OUTPUTS #########################################

% rmapFileName      :   The path of the .rmap file that results from this
%                       registration.

% ####################### Dependencies ####################################

% #########################################################################
% UCL, EVR, 5th June 2019 & RJC, April 2020
%
% ############################# To Do #####################################
% Convert inputs to a single .mshs file, which would be the output of a
% mask-to-meshes function?
% #########################################################################

% ############################# Updates ###################################
% #########################################################################

% MANAGE VARIABLES
% #########################################################################

if ~exist('vol2gm','var')
    radius = 3;
    vol2gm = DOTHUB_vol2gmMap(headVolumeMesh.node,gmSurfaceMesh.node,radius,1);
elseif isempty(vol2gm)
    radius = 3;
    vol2gm = DOTHUB_vol2gmMap(headVolumeMesh.node,gmSurfaceMesh.node,radius,1);
end

% Load SD_3D
load(SD_3DFullFileName,'SD_3D','-mat');

%% AFFINE METHOD (may add other options in future)
regMethod = 'Affine';
% Get affine transformation matrices
[A,B] = DOTHUB_affineMap(landmarks, SD_3D.Landmarks);

% Transform meshnodes;
headVolumeMeshReg = headVolumeMesh;
headVolumeMeshReg.node = DOTHUB_AffineTrans(headVolumeMeshReg.node,A,B);

gmSurfaceMeshReg = gmSurfaceMesh;
gmSurfaceMeshReg.node = DOTHUB_AffineTrans(gmSurfaceMeshReg.node,A,B);

scalpSurfaceMeshReg = scalpSurfaceMesh;
scalpSurfaceMeshReg.node = DOTHUB_AffineTrans(scalpSurfaceMeshReg.node,A,B);

%Ensure sources are on the mesh - first force to scalp, then to volume.
SD_3Dmesh = SD_3D;
for i = 1:SD_3D.nSrcs
    tmp = DOTHUB_nearestNode(SD_3D.SrcPos(i,:),scalpSurfaceMeshReg.node);
    SD_3Dmesh.nSrcs(i) = DOTHUB_nearestNode(tmp,headVolumeMeshReg.node);
end
for i = 1:SD_3D.nDets
    tmp = DOTHUB_nearestNode(SD_3D.DetPos(i,:),scalpSurfaceMeshReg.node);
    SD_3Dmesh.nDets(i) = DOTHUB_nearestNode(tmp,headVolumeMeshReg.node);
end

%% Write out .rmap file ####################################################
% USE CODE SNIPPET FROM DOTHUB_writeRMAP to define name and logData
ds = datestr(now,'yyyymmDDHHMMSS');
[~, origMeshFileName, ~] = fileparts(origMeshFullFileName);
[SD_3DPath, SD_3DFileName, ~] = fileparts(SD_3DFullFileName);
rmapFileName = fullfile(SD_3DPath,[origMeshFileName '_Reg2_' SD_3DFileName '.rmap']);
logData(1,:) = {'Created on: ',ds};
logData(2,:) = {'Positions derived from: ', SD_3DFullFileName};
logData(3,:) = {'Meshes derived from: ', origMeshFullFileName};
logData(4,:) = {'Registration method: ', regMethod};

% Write
[rmap, rmapFileName] = DOTHUB_writeRMAP(rmapFileName,logData,SD_3Dmesh,headVolumeMeshReg,gmSurfaceMeshReg,scalpSurfaceMeshReg,vol2gm);

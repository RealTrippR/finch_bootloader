%define INT_DSK             0x13
%define DSK_RESET_SYSTEM    0
%define DSK_READ_SECTORS    02h
%define KRNL_SEC_CNT        2
%define KRNL_SEC            2 ; NOTE: SECTORS BEGIN INDEXING AT 1
%define KRNL_BEG            0x7E00

%macro STRL_8 1
    %strlen charcnt %1
    db charcnt, %1
%endmacro

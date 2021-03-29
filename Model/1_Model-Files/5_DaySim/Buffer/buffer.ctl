RUNLAB chat buffering
PRNTFN chat_MICROZONE8.prn    print file name
                                              
OUTDIR .\                                     output directory pathname
OUTFNM chatt_MICROZONE_decay.dat    		output parcel buffer file name (file type always ascii)
OUTDLM 1                                      outfile file delimiter (1=space, 2=tab, 3=comma) 
                                              
INPDIR .\                                     input directory pathname
PARCFT 1                                      input parcel file type (1=dbf, 2=ascii - space or tab delimited)
PARCFN Chatanooga_parcelbase.dbf   			input parcel base data file name
INTSFT 1                                      input intersection file type (0=none, 1=dbf, 2=ascii - space or tab delimited)
INTSFN Chatanooga_All_Street_Nodes.dbf                input intersection data file name
TRSTFT 1                                      input transit stop file type (0=none, 1=dbf, 2=ascii - space or tab delimited)
TRSTFN TRANSIT_STOP.dbf                 	input transit stop data file name
OPSPFT 1                                      input open space file type (0=none, 1=dbf, 2=ascii - space or tab delimited)
OPSPFN Chattanooga_Openspace_Final_grid.dbf                    input open space data file name
                                              
DLIMIT 30480.0                                orthogonal distance limit (feet) above which parcels are not considered for buffering
                                              
BTYPE1 2                                      type for buffer 1 (1 = flat, 2 = logistic decay, 3 = exponential decay)
BDIST1 660.0                                 buffer 1 distance (feet) - used in different way depending on buffer type    
DECAY1 0.76                                    buffer 1 decay slope parameter (used for logistic decay type)
EXPON1 -2.5205                                buffer 1 decay exponent (used for exponential decay type)
                                              
BTYPE2 2                                      type for buffer 2 (1 = flat, 2 = logistic decay, 3 = exponential decay)
BDIST2 1320.0                                 buffer 2 distance (feet) - used in different way depending on buffer type    
DECAY2 0.76                                    buffer 2 decay slope parameter (used for logistic decay type)
EXPON2 -0.4365                                buffer 2 decay exponent (used for exponential decay type)

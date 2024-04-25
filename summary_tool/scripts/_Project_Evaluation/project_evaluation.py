import pandas as pd
import geopandas as gpd
import numpy as np
from pathlib import Path


def create_project_evaluation(model_output_path, summary_output_path, scenario, link_query):
    
    link_query_df = pd.read_csv(link_query)
    
    network_df = pd.DataFrame()

    for scen in scenario:
        network_load_path = (model_output_path / scen)
        network = gpd.read_file(network_load_path / 'loaded_network.shp')
        network = network[['ID','DIR','LENGTH','TOTFLOW','AB_TOTFLOW','BA_TOTFLOW',
                        'AB_CTIME','BA_CTIME','FFTIME','AB_AM_TIME','BA_AM_TIME','AB_PM_TIME','BA_PM_TIME']]

        network = network.merge(link_query_df, left_on='ID', right_on='Link_ID', how='right')

        # vmt
        network['VMT'] = network['TOTFLOW'] * network['LENGTH']
        # vhd
        network['VHD'] = ((network['AB_CTIME'] - network['FFTIME']) * network['AB_TOTFLOW'] +
                        (network['BA_CTIME'] - network['FFTIME']) * network['BA_TOTFLOW']
                        )/60
        # peak hour time
        # TODO: check results from post processer
        network.loc[network['DIR']==0, 'AM_PEAK_TIME'] = (network['AB_AM_TIME'] + network['BA_AM_TIME']) / 2
        network.loc[network['DIR'].isin([-1, 1]), 'AM_PEAK_TIME'] = network[['AB_AM_TIME', 'BA_AM_TIME']].max(axis=1)

        network.loc[network['DIR']==0, 'PM_PEAK_TIME'] = (network['AB_PM_TIME'] + network['BA_PM_TIME']) / 2
        network.loc[network['DIR'].isin([-1, 1]), 'PM_PEAK_TIME'] = network[['AB_PM_TIME', 'BA_PM_TIME']].max(axis=1)

        network['Scenario'] = scen
        network_df = pd.concat([network_df, network])


    out_df = (network_df.groupby(['Scenario','Name'])
              .agg({'LENGTH':'sum', 
                    'FFTIME':'sum', 
                    'AM_PEAK_TIME':'sum', 
                    'PM_PEAK_TIME':'sum', 
                    'VMT':'sum',
                    'VHD':'sum'})
                    .reset_index()
              )

    out_df.round(2).to_csv(summary_output_path / 'ProjectEvaluation_{}.csv'.format(link_query.stem), index=False)


if __name__ == "__main__":
    # TODO: these paths and inputs need to be coded as relative paths
    MODEL_OUTPUT_PATH = Path(
        r"C:\Users\USYS671257\Documents\GitHub\client_chattanooga_rtp_update\summary_tool\model_output"
    )
    SUMMARY_OUTPUT_PATH = Path(
        r"C:\Users\USYS671257\Documents\GitHub\client_chattanooga_rtp_update\summary_tool\summary_output"
    )
    # TODO: these inputs need to be read from config file
    SCENARIO = ['2019','2050']
    LINK_QUERY = Path(
        r"C:\Users\USYS671257\Documents\GitHub\client_chattanooga_rtp_update\summary_tool\lookups\cummings_hwy.csv"
    )
    create_project_evaluation(MODEL_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, SCENARIO, LINK_QUERY)
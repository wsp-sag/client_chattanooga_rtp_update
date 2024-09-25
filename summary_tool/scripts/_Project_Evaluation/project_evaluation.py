import pandas as pd
import geopandas as gpd
import numpy as np
from pathlib import Path


def create_project_evaluation(model_output_path, summary_output_path, scenario, link_query):
    
    link_query_df = pd.read_csv(link_query)

    network_df = pd.DataFrame()

    for scen in scenario:
        network_load_path = (model_output_path / str(scen))

        network = gpd.read_file(network_load_path / 'loaded_network.shp')
        network = network[['ID','DIR','LENGTH','AB_LANES','BA_LANES',
                        'TOTFLOW','AB_TOTFLOW','BA_TOTFLOW',
                        'AB_CTIME','BA_CTIME','FFTIME']]

        post_link = gpd.read_file(network_load_path / 'post_links.dbf')
        post_link = post_link[['ID1','PKTIME_AB','PKTIME_BA']].rename(columns={'ID1':'ID'}).fillna(0)

        network = network.merge(link_query_df, left_on='ID', right_on='Link_ID', how='right')
        network = network.merge(post_link, on='ID', how='left')

        # vmt
        network['VMT'] = network['TOTFLOW'] * network['LENGTH']
        # vhd
        network['VHD'] = ((network['AB_CTIME'] - network['FFTIME']) * network['AB_TOTFLOW'] +
                        (network['BA_CTIME'] - network['FFTIME']) * network['BA_TOTFLOW']
                        )/60
        # peak hour time
        network.loc[network['DIR']==0, 'PEAK_TIME'] = (network['PKTIME_AB'] + network['PKTIME_BA']) / 2
        network.loc[network['AB_LANES']>0, 'PEAK_TIME'] = network['PKTIME_AB']
        network.loc[network['BA_LANES']>0, 'PEAK_TIME'] = network['PKTIME_BA']
        network['Scenario'] = scen
        network_df = pd.concat([network_df, network])


    out_df = (network_df.groupby(['Scenario','Name'])
                .agg({'LENGTH':'sum', 
                    'FFTIME':'sum', 
                    'PEAK_TIME':'sum', 
                    'VMT':'sum',
                    'VHD':'sum'})
                    .reset_index()
                )

    out_df.round(2).to_csv(summary_output_path / 'ProjectEvaluation_{}.csv'.format(link_query.stem), index=False)


if __name__ == "__main__":

    create_project_evaluation(MODEL_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, SCENARIO, LINK_QUERY)
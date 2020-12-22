# Chattanooga TPO Model RTP Update
RTP Model Update for the Chattanooga TPO 2023 RTP

## Installation

1. Clone the repository to a directory (e.g., C:\apps)
```
>> git clone https://github.com/wsp-sag/client_chattanooga_rtp_update.git
```
2. Install [Anaconda 64bit Python 3](https://www.anaconda.com/distribution/)

3. Create an ActivitySim-oriented virtual python environment. Recommend using a virtual env with the environment.yml included in this repository.  
*The environment.yml pins releases. The Geopandas package and its underlying supporting packages are notoriously fragile. The pinning in the
environment.yml will ensure that the correct and "stable" versions of libraries are installed.*
```
>> conda env create -f environment.yml
```
4. Switch the Virtual Env
```
>> conda activate chattanooga
```
5. Setup ipythonkernel
```
>> python -m ipykernel install --user --name chattanooga --display-name "Chattanooga"
```
6. Run Jupyter Notebook from project directory
```
>> jupyter notebook
```
7. Navigate, open, and run notebooks.

## Client Contact and Relationship
Repository created in support of Chattanooga TPO model development for the 2023 RTP. Project lead on the client side is [Yuen Lee](mailto:ylee@chattanooga.gov). WSP team member responsible for this repository is [Elias Sanz](mailto:Luis.Elias@wsp.com).

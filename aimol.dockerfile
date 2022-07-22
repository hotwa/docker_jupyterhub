ARG VERSION=1.0
FROM ubuntu:20.04
LABEL author="hotwa<ze.ga@qq.com>" date="2022-06-23"
LABEL description="jupyterhub with python and R"
WORKDIR /tmp/installdir
ARG R_VERSION=4.2.0
ENV DIRPATH /tmp/installdir
ENV PATH /opt/conda/bin:$PATH
ENV RSTUDIO_WHICH_R /opt/conda/bin/R
ENV KITE_ROOT=/home/admin/.local/share/kite
# for ubuntu18.04 set noninteractive
# ENV DEBIAN_FRONTEND=noninteractive
COPY ./config/* $DIRPATH

RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list && \
    apt-get update -y && apt-get upgrade -y && \
    apt-get install -y tzdata && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apt-get install -y gdebi-core curl wget openssh-server vim lrzsz net-tools sudo git --fix-missing && \
    mkdir /root/.ssh && \
    mv $DIRPATH/id_rsa.pub /root/.ssh/authorized_keys && \
    mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    echo 'root:jupyterhub'|chpasswd && \
    sed -ri '/PermitRootLogin /c PermitRootLogin yes' /etc/ssh/sshd_config  && \
    sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    useradd admin -M -d /home/admin -s /bin/bash && echo "admin:jupyter" | chpasswd && mkdir -p /home/admin && chown admin:admin /home/admin -R && \
    echo "admin ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

USER admin
RUN wget --quiet https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda3.sh && \
    sudo mkdir /opt/conda && sudo chown admin:admin /opt/conda && \
    /bin/bash /tmp/miniconda3.sh -b -u -p /opt/conda && \
    sudo ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    . ~/.bashrc && \
    /opt/conda/bin/conda init bash && \
    conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/main/ && \
    conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/cloud/conda-forge/ && \
    conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/cloud/bioconda/ && \
    conda config --add channels https://mirrors.aliyun.com/anaconda/cloud/msys2 && \
    conda config --add channels https://mirrors.aliyun.com/anaconda/cloud/bioconda && \
    conda config --add channels https://mirrors.aliyun.com/anaconda/pkgs/main && \
    conda config --add channels https://mirrors.aliyun.com/anaconda/pkgs/r && \
    conda config --set show_channel_urls yes && \
    conda config --add channels conda-forge && conda config --add channels bioconda && \
    conda config --set remote_read_timeout_secs 6000.0 && \
    conda clean -i && \
    rm -rf /tmp/miniconda3.sh && \
    mkdir ~/.pip && \
    cd ~/.pip && \
    echo "\
    [global]\n\
    index-url = https://mirrors.aliyun.com/pypi/simple/\n\
    \n\
    [install]\n\
    trusted-host=mirrors.aliyun.com\n"\
    > ~/.pip/pip.conf 

# conda install Rstudio
RUN sudo ln -s /lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libncurses.so.5 && \
    sudo ln -s /lib/x86_64-linux-gnu/libreadline.so.8 /lib/x86_64-linux-gnu/libreadline.so.6 && \
    conda install -c r r-irkernel r-base=${R_VERSION} r-essentials -y && \
    wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.02.3-492-amd64.deb -O /tmp/rstudio-server.deb && \
    sudo chmod +x /tmp/rstudio-server.deb && sudo gdebi -n /tmp/rstudio-server.deb && \
    rm -rf /tmp/rstudio-server.deb

# install jupyterhub dependencies
RUN conda install -c conda-forge nodejs jupyterhub jupyterlab=3.2.6 notebook jupyter-rsession-proxy nb_conda_kernels ipykernel git -y && \
    conda install -c conda-forge jupyterlab-language-pack-zh-CN jupyterlab-git jupyterlab-system-monitor jupyter_nbextensions_configurator jupyter_contrib_nbextensions \
    jupyterlab-unfold jupyterlab-variableinspector -y && \
    conda install -c conda-forge nbresuse ipydrawio[all] jedi ipympl black isort theme-darcula ipywidgets \
    tensorboard jupyterlab_execute_time jupyterlab_latex jupyter_bokeh -y && \
    /opt/conda/bin/pip install "jupyterlab-kite>=2.0.2" && \
    conda create -n plot_env python=3 -y && \
    conda install -n plot_env -c conda-forge schedule bokeh seaborn pandas numpy matplotlib requests ipykernel -y && \
    /opt/conda/envs/plot_env/bin/pip install pyg2plot

# create new environment aimol
RUN sudo chown admin:admin /tmp/installdir -R && \
    sudo mkdir -p /home/spawner/NoteBook && sudo mv /tmp/installdir/testGPUavaliabel.ipynb /home/spawner/NoteBook/TestGPUavaliabel.ipynb && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch && \
    conda create -n aimol python=3.9 -y && \
    conda install -n aimol -c conda-forge numpy rdkit ipykernel deepchem==2.6.1 networkx tqdm -y && \
    conda install -n aimol pytorch torchvision torchaudio cudatoolkit=10.2 -c pytorch && \
    conda install -n aimol -c dglteam dgl-cuda11.3 -y && \
    conda install -n aimol -c conda-forge ipywidgets -y && \
    /opt/conda/envs/aimol/bin/pip install tensorflow-gpu~=2.4 && \
    conda create -n plot_env python=3 -y && \
    conda install -n plot_env -c conda-forge ipywidgets ipykernel -y  && \
    conda install -n plot_env -c conda-forge schedule bokeh seaborn pandas numpy matplotlib requests -y && \
    /opt/conda/envs/plot_env/bin/pip install pyg2plot

ADD kite.tar.gz /home/admin/.local/share/
# install kite https://zhuanlan.zhihu.com/p/478749186
RUN mkdir -p /home/admin/.jupyter && mkdir -p /home/admin/NoteBookFiles && \
    echo "c.JupyterHub.authenticator_class ='jupyterhub.auth.DummyAuthenticator'\n\
c.JupyterHub.ip ='0.0.0.0'\n\
c.JupyterHub.port =8000\n\
c.Spawner.ip ='127.0.0.1'\n\
c.Spawner.default_url = '/lab'\n\
c.PAMAuthenticator.encoding ='utf8'\n\
c.Authenticator.allowed_users = {'admin'}\n\
c.LocalAuthenticator.create_system_users =True\n\
c.Authenticator.admin_users = {'admin'}\n\
c.JupyterHub.statsd_prefix ='jupyterhub'\n\
c.Spawner.notebook_dir ='/home/admin/'\n\
c.PAMAuthenticator.open_sessions = False\n\
c.Spawner.env_keep.append('ENV1')\n\
c.Spawner.env_keep.append('ENV2')\n\
c.Spawner.env_keep.append('LD_LIBRARY_PATH')" > /home/admin/.jupyter/jupyterhub_config.py && \
    sudo chown -R admin:admin ${KITE_ROOT} && sudo chmod -R 774 ${KITE_ROOT} && \
    rm ${KITE_ROOT}/current && ln -s ${KITE_ROOT}/kite-v2.20210610.0/ ${KITE_ROOT}/current && \
    rm ${KITE_ROOT}/kite-v2.20210610.0/lib/libtensorflow.so.1 && rm ${KITE_ROOT}/kite-v2.20210610.0/lib/libtensorflow_framework.so.1 && \
    ln -s ${KITE_ROOT}/kite-v2.20210610.0/lib/libtensorflow_framework.so.1.15.0 ${KITE_ROOT}/kite-v2.20210610.0/lib/libtensorflow.so.1 && \
    ln -s ${KITE_ROOT}/kite-v2.20210610.0/lib/libtensorflow_framework.so.1.15.0 ${KITE_ROOT}/kite-v2.20210610.0/lib/libtensorflow_framework.so.1 && \
    sudo chown -R admin:admin /home/admin && sudo chmod -R 774 /home/admin/.local && \
    echo 'sudo nohup /usr/sbin/sshd -D >/dev/null 2>&1 &\n\
nohup ${KITE_ROOT}/kited > /home/admin/.local/kite.log 2>&1 &\n\
source activate base\n\
nohup jupyterhub -f /home/admin/.jupyter/jupyterhub_config.py > /home/admin/.local/jupyter.log 2>&1 &\n\
/bin/bash\n\
    ' > /home/admin/.local/share/entrypoint.sh

WORKDIR /home/admin/.local/share/jupyter
EXPOSE 8000
EXPOSE 22
VOLUME [ "/home/admin" ]
ENTRYPOINT ["/bin/bash","/home/admin/.local/share/entrypoint.sh"]

# install nodejs
# apt-get install gpg -y && \
#     gpg --keyserver keyserver.ubuntu.com --recv 5523BAEEB01FA116 && \
#     gpg --export --armor 5523BAEEB01FA116 | apt-key add - && \
# install with conda, do not need nodejs install 
# RUN wget --quiet https://deb.nodesource.com/setup_14.x -O nodesource_setup.sh && \
#     /bin/bash nodesource_setup.sh && \
#     apt-get install nodejs -y
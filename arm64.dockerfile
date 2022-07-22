ARG VERSION="20.04"
FROM ubuntu:${VERSION}
LABEL author="hotwa<ze.ga@qq.com>" date="2022-07-21"
LABEL description="jupyterhub with python and R"
ARG CREATE_USER="admin"
ARG CREATE_USER_PASSWD="jupyterhub"
ARG ROOT_PASSWD="jupyterhub"
ARG HOME="/home/${CREATE_USER}"
# for ubuntu18.04 ENV DEBIAN_FRONTEND set noninteractive
ARG DEBIAN_FRONTEND="noninteractive"
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}

COPY ./config/id_rsa.pub /root/.ssh/authorized_keys
RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list && \
    apt-get update -y && apt-get upgrade -y && \
    apt-get install -y tzdata && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apt-get install -y gdebi-core curl wget openssh-server vim lrzsz net-tools sudo git --fix-missing && \
    mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    echo 'root:${ROOT_PASSWD}'|chpasswd && \
    sed -ri '/PermitRootLogin /c PermitRootLogin yes' /etc/ssh/sshd_config  && \
    sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    useradd ${CREATE_USER} -M -d /home/${CREATE_USER} -s /bin/bash && echo "${CREATE_USER}:${CREATE_USER_PASSWD}" | chpasswd && mkdir -p /home/${CREATE_USER} && chown ${CREATE_USER}:${CREATE_USER} /home/${CREATE_USER} -R && \
    echo "${CREATE_USER} ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# jupyterhub.auth.DummyAuthenticator 没有用户密码 （测试环境推荐）
# jupyterhub.auth.PAMAuthenticator 与系统用户账号密码一致（生产环境推荐）
ENV PATH /opt/conda/bin:$PATH
# ENV RSTUDIO_WHICH_R /opt/conda/bin/R
# ENV KITE_ROOT="/root/.local/share/kite"
RUN wget --quiet https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py39_4.12.0-Linux-aarch64.sh -O /tmp/miniconda3.sh && \
    mkdir /opt/conda && \
    /bin/bash /tmp/miniconda3.sh -b -u -p /opt/conda && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
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
# for arm64 not the deb package for install, for use arm-RStudio-server please see https://github.com/fdewes/rstudio-server-arm64/blob/main/Dockerfile
# RUN sudo ln -s /lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libncurses.so.5 && \
#     sudo ln -s /lib/x86_64-linux-gnu/libreadline.so.8 /lib/x86_64-linux-gnu/libreadline.so.6 && \
#     sudo wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.02.3-492-amd64.deb -O /tmp/rstudio-server.deb && \
#     sudo chmod +x /tmp/rstudio-server.deb && sudo gdebi -n /tmp/rstudio-server.deb && \
#     sudo rm -rf /tmp/rstudio-server.deb

USER ${CREATE_USER}
WORKDIR ${HOME}

# create jupyterhub_env necessary (jupyter-rsession-proxy)
RUN sudo chown -R ${CREATE_USER}:${CREATE_USER} ${HOME} && \
    conda init bash && \
    conda create -n jupyterhub_env python=3 -y && \
    echo "conda activate jupyterhub_env" >> ~/.bashrc && \
    conda install -n jupyterhub_env -c conda-forge nodejs jupyterhub jupyterlab notebook nb_conda_kernels ipykernel git -y && \
    conda install -n jupyterhub_env -c conda-forge jupyterlab-language-pack-zh-CN jupyterlab-git jupyterlab-system-monitor jupyter_nbextensions_configurator jupyter_contrib_nbextensions \
    jupyterlab-unfold jupyterlab-variableinspector -y && \
    conda install -n jupyterhub_env -c conda-forge nbresuse ipydrawio[all] jedi ipympl black isort theme-darcula ipywidgets \
    tensorboard jupyterlab_execute_time jupyterlab_latex jupyter_bokeh -y
    
# create plot_env
RUN conda create -n plot_env python=3 -y && \
    conda install -n plot_env -c conda-forge schedule bokeh seaborn pandas numpy matplotlib requests ipykernel -y && \
    /home/${CREATE_USER}/.conda/envs/plot_env/bin/pip install pyg2plot

# ARG R_VERSION="4.2.0"
# ENV R_VERSION=${R_VERSION}
# ENV RSTUDIO_WHICH_R ~/.conda/envs/r_env/bin/R
# # create r_env
# RUN conda install -n jupyterhub_env -c r r-irkernel r-base=${R_VERSION} r-essentials -y && \
#     conda install -n jupyterhub_env -c conda-forge radian jupyter-rsession-proxy nb_conda_kernels -y && \
#     conda create -n r_env python=3 -y && \
#     conda install -n r_env -c r r-irkernel r-base=${R_VERSION} r-essentials -y && \
#     conda install -n r_env -c conda-forge radian jupyter-rsession-proxy nb_conda_kernels -y

# install kite https://zhuanlan.zhihu.com/p/478749186
# install kite only for single user, not support muti-users
# kite.tar.gz not support arm64 to install
# ADD kite.tar.gz ./.local/share/
# ENV KITE_ROOT="${HOME}/.local/share/kite"
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}
ENV PATH /opt/conda/bin:$PATH
ARG JUPYTER_AUTHENTICATOR_CLASS="jupyterhub.auth.PAMAuthenticator"
RUN mkdir -p ./.jupyter && \
    echo "c.JupyterHub.authenticator_class ='${JUPYTER_AUTHENTICATOR_CLASS}'\n\
c.JupyterHub.ip ='0.0.0.0'\n\
c.JupyterHub.port =8000\n\
c.Spawner.ip ='127.0.0.1'\n\
c.Spawner.default_url = '/lab'\n\
c.PAMAuthenticator.encoding ='utf8'\n\
c.Authenticator.allowed_users = {'root', 'admin'}\n\
c.LocalAuthenticator.create_system_users = True\n\
c.Authenticator.admin_users = {'root', 'admin'}\n\
c.Spawner.args = ['--allow-root']\n\
c.JupyterHub.statsd_prefix ='jupyterhub'\n\
c.Spawner.notebook_dir ='~/jupyterhub_data'\n\
c.JupyterHub.shutdown_on_logout = True\n\
c.PAMAuthenticator.open_sessions = True\n\
c.Spawner.env_keep.append('ENV1')\n\
c.Spawner.env_keep.append('ENV2')\n\
c.Spawner.env_keep.append('LD_LIBRARY_PATH')" > ./.jupyter/jupyterhub_config.py && \
    mkdir -p ./.local && \
    sudo chown -R ${CREATE_USER}:${CREATE_USER} ./.local && \
    echo 'sudo nohup /usr/sbin/sshd -D >/dev/null 2>&1 &\n\
source activate jupyterhub_env\n\
nohup jupyterhub -f ./jupyterhub_config.py > ./jupyter.log 2>&1 &\n\
/bin/bash\n\
    ' > ./.jupyter/entrypoint.sh

# https://blog.csdn.net/weixin_42902669/article/details/108896133
EXPOSE 8000
EXPOSE 22
VOLUME "${HOME}/jupyterhub_data"
WORKDIR "${HOME}/.jupyter"
ENTRYPOINT ["/bin/bash","./entrypoint.sh"]

# docker run --name myjupyterhub --restart unless-stopped -p 48888:8000 -p 48822:22 -v /C/Users/user/hotwaprogram/dockerfiles/jupyterhub/test_data:/home/admin/jupyterhub_data -itd hotwa/jupyterhub:latest
# docker buildx build --platform linux/amd64,linux/arm64 -t hotwa/jupyterhub:latest -f .\admin.dockerfile . 
# install nodejs
# apt-get install gpg -y && \
#     gpg --keyserver keyserver.ubuntu.com --recv 5523BAEEB01FA116 && \
#     gpg --export --armor 5523BAEEB01FA116 | apt-key add - && \
# install with conda, do not need nodejs install 
# RUN wget --quiet https://deb.nodesource.com/setup_14.x -O nodesource_setup.sh && \
#     /bin/bash nodesource_setup.sh && \
#     apt-get install nodejs -y
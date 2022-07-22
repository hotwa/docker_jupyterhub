# Best jupyterhub for Scientists

[dockerhub](https://hub.docker.com/repository/docker/hotwa/jupyterhub)

## Support
kite engine
RStudio Server R=4.2 (radian)
miniconda3(python=3.9 default)

# Usage

```shell
# for mainland
docker pull registry.cn-hangzhou.aliyuncs.com/hotwa/jupyterhub:<version> # version arm64 or latest(x64)
docker pull registry.cn-hangzhou.aliyuncs.com/hotwa/jupyterhub:latest
# for outside
docker pull hotwa/jupyterhub:<version>
```

## start containers

```shell
docker run --name myjupyterhub --restart unless-stopped -p 48888:8000 -p 48822:22 -v <your_dir>:/home/admin/jupyterhub_data -itd hotwa/jupyterhub:latest
```

default user: admin
default passwd: jupyterhub

```shell
# jupyterhub.auth.DummyAuthenticator 没有用户密码 （测试环境推荐）
# jupyterhub.auth.PAMAuthenticator 与系统用户账号密码一致（生产环境推荐）
```


<!--
 * @Author: LetMeFly
 * @Date: 2026-07-31 17:13:20
 * @LastEditors: LetMeFly.xyz
 * @LastEditTime: 2026-07-31 17:43:45
-->
# my_docker_pull

通过github->阿里云私有容器服务->公网服务器的docker pull

## 工作原理

```mermaid
flowchart TD
    A[目标服务器<br/>执行 my_docker_pull IMAGE:TAG] --> B{本地是否存在镜像?}

    B -->|是| C[直接使用镜像]

    B -->|否| D{阿里云私有镜像仓库<br/>是否存在?}

    D -->|是| E[从阿里云拉取镜像<br/>（SHA校验）]
    E --> F[返回镜像]

    D -->|否| G[API触发 GitHub Actions]

    G --> H[GitHub Actions<br/>拉取源镜像并推送到<br/>阿里云私有镜像仓库]

    H --> I[Callback Hook<br/>通知目标服务器]

    I --> J[从阿里云拉取镜像<br/>SHA校验]

    J --> F


    subgraph Server[目标服务器]
        A
        B
        D
        E
        I
        J
    end

    subgraph GitHub[GitHub]
        G
        H
    end

    subgraph ACR[阿里云私有镜像仓库<br/>Docker镜像缓存层]
        E
        H
    end
```

## 致谢

Idea inspeared by [Github@you8023/docker_images_sync](https://github.com/you8023/docker_images_sync/tree/338c58fe2d2b71d124b9dd62dffa6cf4861f0c06)，不同之处在于：

+ 本仓库面向有公网IP但未配置特殊网络的服务器，需要具备公网IP或内网穿透
+ 无需每次产生非feat的commit记录，改用api触发action
+ 改用回调机制，GitHub Workflow推送至阿里云镜像后hook主机，无需每20秒轮询
+ 拉取后校验sha
+ 检查本地及阿里云私有容器服务是否已经存在该镜像，若已存在则不再触发GitHub工作流

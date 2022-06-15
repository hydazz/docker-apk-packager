## docker-apk-packager

[![docker hub](https://img.shields.io/badge/docker_hub-link-blue?style=for-the-badge&logo=docker)](https://hub.docker.com/r/vcxpz/apk-packager) ![docker image size](https://img.shields.io/docker/image-size/vcxpz/apk-packager?style=for-the-badge&logo=docker) [![auto build](https://img.shields.io/badge/docker_builds-automated-blue?style=for-the-badge&logo=docker?color=d1aa67)](https://github.com/hydazz/docker-apk-packager/actions?query=workflow%3A"Auto+Builder+CI")

apk-packager is a Docker image with an accompanying script to automate building and packaging apk packages via abuild for any architecture from any architecture.

## Getting started ( Linux / macOS )

Download the script.

```bash
wget https://raw.githubusercontent.com/hydazz/docker-apk-packager/main/build.sh
```

Allow the file to be executed.

```bash
chmod +x build.sh
```

Run the script **(example, see below)**.

```bash
./build.sh -v latest -a <arch> -k <key> -i <input> -o <output>
```

The docker container can also be ran standalone, without the script

```bash
 docker run -it --rm -v <input>:/config/apk-build -v <output>:/out -e testing=true vcxpz/apk-packager
```

`<input>` is the directory the APKBUILD file resides in, not the APKBUILD file

| Name | Description                                                                                                                                                                                                                               | Example                                                 |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `-v` | **(Optional)** The Alpine version that will be used when building the package. Defaults to `latest`. See [supported Alpine versions](#supported-architectures--alpine-versions).                                                          | `-v latest`                                               |
| `-a` | **(Optional)** The architecture that the builder will run on. Creating an apk file for that specific architecture. Defaults to what architecture your system is. See [supported architectures](#supported-architectures--alpine-versions). | `-a amd64`                                              |
| `-k` | **(Optional)\*** Path to your private key generated by abuild-keygen. This path must be absolute!                                                                                                                                         | `-k /path/to/key.rsa`                                   |
| `-i` | **(Required)** The location of the APKBUILD file.                                                                                                                                                                                         | `-i /path/to/package` or `-i /path/to/package/APKBUILD` |
| `-o` | **(Required)** The folder the .apk files will be saved to.                                                                                                                                                                                | `-o /output/directory`                                  |
| `-t` | **(Optional)** Append to enable the testing repository.                                                                                                                                                                                   | `-t`                                                    |

\*_If no private key is specified, one will be generated in the output directory._

Putting these all together in a command:

```bash
./build.sh -v latest -a amd64 -k /path/to/key.rsa -i /path/to/package -o /output/directory -t
```

If the build was successful, you should see `Build successful!` in the terminal. If you do not see this message, check the terminal for errors.

### Building the same package for multiple architectures

I have not incorporated an easy way to do this in the scripts, but running the commands separately doesn't hurt. Here's an example of building for all supported architectures.

```bash
#!/bin/bash
for arch in amd64 arm/v6 arm/v7 arm64 i386 ppc64le s390x; do
    ./build.sh -a $arch -k <key> -i <input> -o <output>
done
```

This will create the `apk-packager` folder in the `<output>` directory. Depending on what architectures you used, the folder will have separate subfolders for each architecture.

### Building multiple packages for one or multiple architectures

This is a big no-no, the `APKINDEX.tar.gz` file will be overwritten, and everything will just become a mess. To get past this hurdle extract the `APKINDEX.tar.gz` archive. There will be an APKINDEX text file within the archive. Move this file somewhere safe and delete the `APKINDEX.tar.gz` archive from the directory. Then you can run the build command. Once the build command is done, follow these steps:

-   Extract the newer `APKINDEX.tar.gz` (make sure its the new one, the only one should be deleted but whatever)
-   Open the newer `APKINDEX` file that was extracted from the newer `APKINDEX.tar.gz`
-   Copy the contents of the old `APKINDEX` file and paste them at the bottom of the new one. make sure there is one space between the packages

**Below is ran within an Alpine container.**

-   On a fresh Alpine Docker container, mount the `apk-packager` folder within the container and run `apk add alpine-sdk`
-   `cd` to the folder containing the modified `APKINDEX` file
-   run `tar -c APKINDEX | abuild-tar --cut | gzip -9 >APKINDEX.tar.gz` to make a `APKINDEX.tar.gz` archive from the file
-   Run `abuild-sign -k /path/to/private_key.rsa APKINDEX.tar.gz` to sign the index

Follow these steps for every package and architecture; it does get tedious.

## Tested / Supported Building OS's

From my testing, building seems to work on any OS that supports Docker and QEMU.

| OS                         | Notes                                                |
| -------------------------- | ---------------------------------------------------- |
| Ubuntu/Debian              | Requires some setting up, [see here](#ubuntudebian). |
| macOS (via Docker Desktop) | jq should be installed, [see here](#macos)           |

Jq and Docker buildx is only required when building for architectures that are not the hosts.

## Setting Environment ( Dependencies )

### macOS

macOS only requires Docker Desktop and jq to be installed for everything to work smoothly. Docker desktop can be downloaded from docker's [website](https://www.docker.com/products/docker-desktop).

jq can be installed via brew:

```bash
brew install jq
```

### Ubuntu/Debian

Ubuntu/Debian doesn't have docker desktop, so setup is a little more complicated, qemu, jq, docker and docker buildx have to be installed.

**Installing Docker:**

```bash
curl -sSL https://get.docker.com | bash
```

The above command should automatically install docker and docker buildx if it did not install buildx (which can be validated by running `docker buildx ls`). Try manually installing as shown below.

**Manually Installing Docker Buildx:**

Docker Buildx is included in Docker Desktop and Docker Linux packages when installed using the DEB or RPM packages.

You can also download the latest buildx binary from the Docker buildx releases page on GitHub, copy it to ~/.docker/cli-plugins folder with name docker-buildx and change the permission to execute:

```bash
chmod a+x ~/.docker/cli-plugins/docker-buildx
```

Verify Docker Buildx installation by running:

```bash
docker buildx ls
```

See [here](https://github.com/docker/buildx/#installing) for more help installing docker buildx.

**Installing jq:**

```bash
apt-get install jq
```

### Configure QEMU Multi-Arch Support

Docker Desktop comes with multi-arch support out of the box. If you are running on any other operating system than macOS or Windows that does not have docker desktop, you will need to install QEMU to achieve full multi-arch buildx,

```bash
apt-get install qemu-user-static
```

### Verify you can run other architectures on your system

Run `docker buildx ls`. This will give you a list of architectures your system can emulate.

    NAME/NODE  DRIVER/ENDPOINT STATUS PLATFORMS
    ...
    ... linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6

## Supported Architectures / Alpine Versions

Currently, all architectures are supported on the latest Alpine versions. Feel free to open an issue if you need a specific Alpine version.

| Platform       | Alpine versions, `-v` Input | `-a` Input | Name of output folder |
| -------------- | --------------------------- | ---------- | --------------------- |
| linux/amd64    | edge, latest, 3.15          | `amd64`    | `x86_64`              |
| linux/arm/v6   | edge, latest, 3.15          | `arm/v6`   | `armhf`               |
| linux/arm/v7   | edge, latest, 3.15          | `arm/v7`   | `armv7`               |
| linux/arm64/v8 | edge, latest, 3.15          | `arm64`    | `aarch64`             |
| linux/386      | edge, latest, 3.15          | `386`      | `x86`                 |
| linux/ppc64le  | edge, latest, 3.15          | `ppc64le`  | `ppc64le`             |
| linux/s390x    | edge, latest, 3.15          | `s390x`    | `s390x`               |

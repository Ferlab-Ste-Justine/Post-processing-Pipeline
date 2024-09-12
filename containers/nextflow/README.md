This docker image is designed to create long-running Nextflow pods. It includes nextflow and several command-line
utilities such as the AWS CLI and Rclone. Additionally, it provides more basic linux commands like tar, which are 
not included in the base nextflow image.

## Local Testing Commands

To build it locally, you can use the following command from the project root directory:

```
docker build containers/nextflow -t ferlabcrsj/nextflow:dev
```


To open a shell on a docker container created from this image, run the following command:

```
docker run -it --rm ferlabcrsj/nextflow:dev /bin/bash
```

Since the `--rm` option is specified, the container will be automatically deleted once you exit the shell.

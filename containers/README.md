## Containers

### Nextflow
This docker image is designed to create long-running Nextflow pods. It includes nextflow and several command-line
utilities such as the AWS CLI and Rclone. Additionally, it provides more basic linux commands like tar, which are 
not included in the base nextflow image.

### Exomiser

This Docker image is based on the official exomiser Docker image exomiser exomiser-cli:14.0.0-bash. 
It is modified for compatibility with nextflow.

### Exomiser-13

This is a docker image allowing to run exomiser 13.1.0. One can substitute the resulting image with our default
exomiser image to run the pipeline with exomser 13.1.0.

## Local Testing Commands
Here is an example for the Nextflow image. You can adapt these commands for other images as needed.
#### Building the Docker Image #### 

To build it locally, you can use the following command from the project root directory:

```
docker build containers/nextflow -t ferlabcrsj/nextflow:dev
```

#### Running the Docker Container ####
To open a shell on a docker container created from this image, run the following command:

```
docker run -it --rm ferlabcrsj/nextflow:dev /bin/bash
```


Since the `--rm` option is specified, the container will be automatically deleted once you exit the shell.

If you are using a different image, make sure to change the image tag (ferlabcrsj/nextflow:dev) accordingly.

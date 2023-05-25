# TMAS Container

## Description

`tmas` is a CLI tool that performs open source vulnerability scanning and report generation for artifacts. It first takes the artifact that you wish to be scanned and generates a Software Bill of Materials (SBOM). The SBOM is then uploaded to Cloud One for processing, and a vulnerability report is returned to the CLI user.

This container is to ease the usage of tmas within pipelines. It can fail the pipeline run if a user defined a vulnerability threshold for the image is exceeded.

## Getting Started

1. Clone the repository.

```sh
git clone https://github.com/mawinkler/c1-cs-tmas
```

2. Navigate to the directory.

```sh
cd c1-cs-tmas
```

3. Build the image.

```sh
docker build -t tmas .
```

4. (Optional) Push the image to your registry.

```sh
docker tag tmas registry:yourrepo/tmas:latest
docker push registry:yourrepo/tmas:latest
```

5. Create a scan.

Usage:

```sh
docker run --rm --name tmas \
  -e CLOUD_ONE_API_KEY=<YOUR API KEY HERE> \
  tmas [OPTION...] registry:<YOUR ARTIFACT HERE>
```

Examples:

```sh
docker run --rm --name tmas \
  -e CLOUD_ONE_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxx:xxxxxx... \
  tmas -t medium registry:public.ecr.aws/g1k6g7f0/shell:latest
```

Options        | Description
-------------- | ---------------------------
`-e URL`       | Endpoint to use
`-v`           | Be verbose
`-r REGION`    | Cloud One region to use
`-t THRESHOLD` | <`any`, `critical`, `high`, `medium`, `low`><br>See below

Threshold   | Description
----------- | --------------------------------
`any`       | Fail if any vulnerability
`critical`  | Fail on critical vulnerabilities
`high`      | Fail on high or higher (default)
`medium`    | Fail on medium or higher
`low`       | Fail on low or higher

If the vulnerability threshold is exceeded the container will exit with exit code `1`.

> ***Note:*** If you need to proxy to Cloud One simply add the documented environment variables to the docker run command.

## Support

This is an Open Source community project. Project contributors may be able to help, depending on their time and availability. Please be specific about what you're trying to do, your system, and steps to reproduce the problem.

For bug reports or feature requests, please [open an issue](../../issues). You are welcome to [contribute](#contribute).

Official support from Trend Micro is not available. Individual contributors may be Trend Micro employees, but are not official support.

## Contribute

I do accept contributions from the community. To submit changes:

1. Fork this repository.
1. Create a new feature branch.
1. Make your changes.
1. Submit a pull request with an explanation of your changes or additions.

I will review and work with you to release the code.

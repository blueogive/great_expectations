# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# FROM ubuntu:bionic-20191202
FROM python:3.7.7

USER root

RUN apt-get update --fix-missing \
    && apt-get install -y --no-install-recommends \
        # bzip2 \
        # ca-certificates \
        # curl \
        # gdebi-core \
        # git \
        # gnupg2 \
        # gosu \
        # libapparmor1 \
        # libclang-dev \
        # libssl1.0-dev \
        # locales \
        # lsb-release \
        make \
        # psmisc \
        # sudo \
        # wget \
        # build-essential \
        # fonts-texgyre \
        # gfortran \
        # default-jdk \
        # dpkg \
        # pandoc \
        # pandoc-citeproc \
        unzip \
        # less \
        # libgomp1 \
        # libpango-1.0-0 \
        # libxt6 \
        # libsm6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

## Install Microsoft and Postgres ODBC drivers and SQL commandline tools
RUN curl -o microsoft.asc https://packages.microsoft.com/keys/microsoft.asc \
    && apt-key add microsoft.asc \
    && rm microsoft.asc \
    && curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        msodbcsql17 \
        mssql-tools \
        odbc-postgresql \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/apt/sources.list.d/mssql-release.list

## Set environment variables
ENV LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    PATH=/opt/conda/bin:/opt/mssql-tools/bin:${PATH} \
    SHELL=/bin/bash \
    CT_USER=docker \
    CT_UID=1000 \
    CT_GID=100 \
    CT_FMODE=0775 \
    CONDA_DIR=/opt/conda

ENV HOME=/home/${CT_USER}

RUN wget --quiet \
    https://repo.anaconda.com/miniconda/Miniconda3-4.7.12.1-Linux-x86_64.sh \
    -O /root/miniconda.sh && \
    if [ "`md5sum /root/miniconda.sh | cut -d\  -f1`" = "81c773ff87af5cfac79ab862942ab6b3" ]; then \
        /bin/bash /root/miniconda.sh -b -p /opt/conda; fi && \
    rm /root/miniconda.sh && \
    /opt/conda/bin/conda clean -tipsy && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Add a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions

## Set a default user. Available via runtime flag `--user docker`
## User should also have & own a home directory (e.g. for linked volumes to work properly).
RUN useradd --create-home --uid ${CT_UID} --gid ${CT_GID} --shell ${SHELL} ${CT_USER} \
    && chmod 0755 /usr/local/bin/fix-permissions

RUN fix-permissions ${CONDA_DIR} \
    && fix-permissions ${HOME} \
    && fix-permissions ${HOME}/.conda

WORKDIR ${HOME}

USER ${CT_USER}

ARG CONDA_ENV_FILE=${CONDA_ENV_FILE}
COPY ${CONDA_ENV_FILE} ${CONDA_ENV_FILE}
RUN /opt/conda/bin/conda update -n base -c defaults conda \
    && /opt/conda/bin/conda config --add channels conda-forge \
    && /opt/conda/bin/conda config --set channel_priority strict

RUN /opt/conda/bin/conda install conda-build --yes \
    && /opt/conda/bin/conda env update -n base --file ${CONDA_ENV_FILE} \
    && /opt/conda/bin/conda build purge-all \
    && rm ${CONDA_ENV_FILE} \
    && fix-permissions ${HOME}

RUN echo ". /opt/conda/etc/profile.d/conda.sh" >> ${HOME}/.bashrc && \
    echo "conda activate base" >> ${HOME}/.bashrc && \
    mkdir ${HOME}/work
SHELL [ "/bin/bash", "--login", "-c"]
ARG PIP_REQ_FILE=${PIP_REQ_FILE}
COPY ${PIP_REQ_FILE} ${PIP_REQ_FILE}
RUN source ${HOME}/.bashrc \
    && conda activate base \
    && git clone https://github.com/blueogive/pyncrypt.git \
    && pip install --user --no-cache-dir --disable-pip-version-check pyncrypt/ \
    && rm -rf pyncrypt \
    && pip install --user --no-cache-dir --disable-pip-version-check \
      -r ${PIP_REQ_FILE} \
    && rm ${PIP_REQ_FILE} \
    && mkdir -p .config/pip \
    && fix-permissions ${HOME}/work
COPY pip.conf .config/pip/pip.conf
WORKDIR ${HOME}/work

ARG VCS_URL=${VCS_URL}
ARG VCS_REF=${VCS_REF}
ARG BUILD_DATE=${BUILD_DATE}

# Add image metadata
LABEL org.label-schema.license="https://opensource.org/licenses/MIT" \
    org.label-schema.vendor="Dockerfile provided by Mark Coggeshall" \
    org.label-schema.name="Great Expectations" \
    org.label-schema.description="Docker image including great_expectations package for testing data pipelines based on Miniconda and Python 3." \
    org.label-schema.vcs-url=${VCS_URL} \
    org.label-schema.vcs-ref=${VCS_REF} \
    org.label-schema.build-date=${BUILD_DATE} \
    maintainer="Mark Coggeshall <mark.coggeshall@gmail.com>"

USER ${CT_USER}

WORKDIR ${HOME}/work

CMD [ "/bin/bash" ]

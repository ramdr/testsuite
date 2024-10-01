# Define build argument for architecture
ARG TARGETARCH

# Base image for amd64
FROM quay.io/centos/centos:stream9 AS amd64_base

# Base image for s390x
FROM quay.io/centos/centos:s390x-stream9 AS s390x_base

# Common installation commands
# For amd64
FROM amd64_base AS builder_amd64
ARG TARGETARCH
LABEL description="Run Kuadrant integration tests \
Default ENTRYPOINT: 'make' and CMD: 'test' \
Bind dynaconf settings to /opt/secrets.yaml \
Bind kubeconfig to /opt/kubeconfig \
Bind a dir to /test-run-results to get reports "

RUN useradd --no-log-init -u 1001 -g root -m testsuite && \
    dnf install -y python3.11 python3.11-pip make git && \
    dnf clean all

RUN curl -LO "https://dl.k8s.io/release/v1.30.2/bin/linux/amd64/kubectl" && \
    mv kubectl /usr/local/bin && \
    chmod +x /usr/local/bin/kubectl

RUN curl -L https://github.com/cloudflare/cfssl/releases/download/v1.6.4/cfssl_1.6.4_linux_amd64 -o /usr/bin/cfssl && \
    chmod +x /usr/bin/cfssl

RUN python3.11 -m pip install cryptography==3.3.2
RUN python3.11 -m pip --no-cache-dir install poetry

WORKDIR /opt/workdir/kuadrant-testsuite

COPY . .

RUN mkdir -m 0770 /test-run-results && mkdir -m 0750 /opt/workdir/virtualenvs && \
    chown testsuite /test-run-results && chown testsuite -R /opt/workdir/*

RUN touch /run/kubeconfig && chmod 660 /run/kubeconfig && chown testsuite /run/kubeconfig

USER testsuite

ENV KUBECONFIG=/run/kubeconfig \
    SECRETS_FOR_DYNACONF=/run/secrets.yaml \
    POETRY_VIRTUALENVS_PATH=/opt/workdir/virtualenvs/ \
    junit=yes \
    resultsdir=/test-run-results

RUN make poetry-no-dev && rm -Rf $HOME/.cache/*

# For s390x
FROM s390x_base AS builder_s390x
ARG TARGETARCH
LABEL description="Run Kuadrant integration tests \
Default ENTRYPOINT: 'make' and CMD: 'test' \
Bind dynaconf settings to /opt/secrets.yaml \
Bind kubeconfig to /opt/kubeconfig \
Bind a dir to /test-run-results to get reports "

RUN useradd --no-log-init -u 1001 -g root -m testsuite && \
    dnf install -y python3.11 python3.11-pip python3.11-devel openssl-devel libffi-devel make git gcc gcc-c++ rust cargo && \
    dnf clean all

RUN curl -LO "https://dl.k8s.io/release/v1.30.2/bin/linux/s390x/kubectl" && \
    mv kubectl /usr/local/bin && \
    chmod +x /usr/local/bin/kubectl

RUN curl -L https://github.com/cloudflare/cfssl/releases/download/v1.6.4/cfssl-bundle_1.6.5_linux_s390x -o /usr/bin/cfssl && \
    chmod +x /usr/bin/cfssl

RUN python3.11 -m pip install cryptography==3.3.2
RUN python3.11 -m pip --no-cache-dir install poetry

WORKDIR /opt/workdir/kuadrant-testsuite

COPY . .

RUN mkdir -m 0770 /test-run-results && mkdir -m 0750 /opt/workdir/virtualenvs && \
    chown testsuite /test-run-results && chown testsuite -R /opt/workdir/*

RUN touch /run/kubeconfig && chmod 660 /run/kubeconfig && chown testsuite /run/kubeconfig

USER testsuite

ENV KUBECONFIG=/run/kubeconfig \
    SECRETS_FOR_DYNACONF=/run/secrets.yaml \
    POETRY_VIRTUALENVS_PATH=/opt/workdir/virtualenvs/ \
    junit=yes \
    resultsdir=/test-run-results

RUN make poetry-no-dev && rm -Rf $HOME/.cache/*

# Final image selection based on TARGETARCH
FROM amd64_base AS final_amd64
COPY --from=builder_amd64 /opt/workdir/kuadrant-testsuite /opt/workdir/kuadrant-testsuite

FROM s390x_base AS final_s390x
COPY --from=builder_s390x /opt/workdir/kuadrant-testsuite /opt/workdir/kuadrant-testsuite

# Select the final image based on TARGETARCH
ARG TARGETARCH
FROM final_amd64 AS final
COPY --from=final_amd64 /opt/workdir/kuadrant-testsuite /opt/workdir/kuadrant-testsuite
RUN ["make"]

FROM final_s390x AS final
COPY --from=final_s390x /opt/workdir/kuadrant-testsuite /opt/workdir/kuadrant-testsuite
RUN ["make"]

ENTRYPOINT [ "make" ]
CMD [ "test" ]

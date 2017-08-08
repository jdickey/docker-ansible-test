FROM williamyeh/ansible:ubuntu16.04
ARG pubkey
ARG seckey
ARG apikey
ARG username=jeff

WORKDIR /tmp
COPY inventory /tmp
COPY playbook.yml /tmp
COPY roles /tmp/roles
COPY .vault-password vault-password-file

# RUN apt-get update && apt-get upgrade -y && apt-get install -y aptitude apt-utils wget sudo && apt-get clean
RUN echo username is $username
RUN apt-get update && apt-get install -f -y aptitude apt-utils curl wget sudo && apt-get clean
RUN wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py && rm get-pip.py
RUN pip install dopy
RUN echo $username && useradd -s /bin/bash --create-home $username
WORKDIR /home/$username
RUN mkdir .ssh
RUN echo $pubkey > .ssh/id_rsa.pub && echo $seckey > .ssh/id_rsa
RUN chmod 644 .ssh/id_rsa.pub && chmod 600 .ssh/id_rsa && chmod 700 .ssh
RUN cp -a /tmp/inventory /tmp/playbook.yml /tmp/roles . && cp -a /tmp/vault-password-file .vault-password

# Install Node and doclt
RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
RUN apt-get install -y nodejs && npm install -g doclt
RUN echo export DOCLT_TOKEN=$apikey > .env
RUN chown -R $username /home/$username
# RUN ansible-playbook -i inventory playbook.yml

# ==> Creating inventory file...
# RUN echo localhost > inventory

# ==> Executing Ansible...
# RUN ansible-playbook -i inventory playbook.yml --connection=local --sudo

ENTRYPOINT bash


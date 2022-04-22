export GODEBUG="x509ignoreCN=0"
export VERSION="4.10.9"
export OCP_RELEASE="4.10.9"
export ARCHITECTURE="aarch64"
export UPSTREAM_REPO='openshift-release-dev'
export OCP_ARCH="aarch64"
export RELEASE_NAME="ocp-release"
export PATH=$PATH:/home/auser:/home/registry
export CMD=openshift-install
export EXTRACT_DIR=$(pwd)
export PULLSECRET=/home/auser/pull-secret.json
export REGISTRY_BASE=/home/registry

curl -s https://mirror.openshift.com/pub/openshift-v4/$ARCHITECTURE/clients/ocp/$VERSION/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc
sudo cp ./oc /usr/local/bin/oc
export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/$ARCHITECTURE/clients/ocp/$VERSION/release.txt| grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)
oc adm release extract --registry-config "${PULLSECRET}" --command=$CMD --to "${EXTRACT_DIR}" ${RELEASE_IMAGE}


sudo dnf -y install podman httpd httpd-tools
sudo mkdir -p ${REGISTRY_BASE}/{auth,certs,data}
sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${REGISTRY_BASE}/certs/domain.key -x509 -days 365 -out ${REGISTRY_BASE}/certs/domain.crt -subj "/C=US/ST=California/L=Santa Clara/O=mrdojojo/OU=Marketing/CN=registry.ocp4.mrdojojo" -addext "subjectAltName = DNS:registry.ocp4.mrdojojo" -addext "certificatePolicies = 1.2.3.4"
sudo cp ${REGISTRY_BASE}/certs/domain.crt /home/auser/domain.crt
sudo chown auser:auser /home/auser/domain.crt
sudo cp ${REGISTRY_BASE}/certs/domain.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract
sudo htpasswd -bBc ${REGISTRY_BASE}/auth/htpasswd dummy dummy

echo 'podman run --name poc-registry --rm -d -p 5000:5000 \
-v ${REGISTRY_BASE}/data:/var/lib/registry:z \
-v ${REGISTRY_BASE}/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
-e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v ${REGISTRY_BASE}/certs:/certs:z \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
docker.io/library/registry:2' > ${REGISTRY_BASE}/downloads/tools/start_registry.sh

podman ps
podman port -a

sleep 10

export REG_SECRET==`echo -n 'dummy:dummy' | base64 -w0`
export PULLSECRET=/home/auser/pull-secret.json
export LOCAL_REG='registry.ocp4.mrdojojo.com:5000'
export LOCAL_REPO='ocp4/openshift4'


cat pull-secret.json | jq '.auths += {"registry.ocp4.mrdojojo.com:5000": {"auth": "REG_SECRET","email": "j@mrdojojo.com"}}' | sed "s/REG_SECRET/$REG_SECRET/" > ${REGISTRY_BASE}/downloads/secrets/pull-secret-bundle.json
cat pull-secret-bundle.json | jq
echo '{ "auths": {}}' | jq '.auths += {"registry.ocp4.mrdojojo.com:5000": {"auth": "REG_SECRET","email": "j@mrdojojo.com"}}' | sed "s/REG_SECRET/$REG_SECRET/" | jq -c .> pull-secret-registry.json

export LOCAL_SECRET_JSON="${REGISTRY_BASE}/downloads/secrets/pull-secret-bundle.json" 

oc adm release mirror -a ${LOCAL_SECRET_JSON}  \
--from=quay.io/${UPSTREAM_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} \
--to=${LOCAL_REG}/${LOCAL_REPO} \
--to-release-image=${LOCAL_REG}/${LOCAL_REPO}:${VERSION} 

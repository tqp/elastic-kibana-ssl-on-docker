# tqp-elasticsearch
These are Tim's instructions on how to build a secure, three-node Elasticsearch cluster with Kibana using Docker.  
They are a blend of many sources, including the following page:  
https://www.elastic.co/guide/en/elastic-stack-get-started/7.17/get-started-docker.html

## Preparation and Notes
I chose not to use a shared environment file of any kind. This adds some additional complexity, 
since you'll have to modify individual files, but for me, it helped me get a better idea of what's
going on in each step.

I wanted to put everything in one directory, for simplicity.

Before you start, figure out what version of Elasticsearch you want to install:
  * 
  * At the time this was published, it was 7.17.0
  * The Kibana version will match the Elasticsearch version.

## Build the Elasticsearch Image
* Modify 'elasticsearch-dockerfile' to use the desired version of Elasticsearch:
  * `FROM docker.elastic.co/elasticsearch/elasticsearch:7.17.0`
* Modify 'elasticsearch-image-builder.sh' to use the desired version of Elasticsearch:
  * `ELASTICSEARCH_IMAGE_TAG=tqp1-elasticsearch:7.17.0`
* Run 'elasticsearch-image-builder.sh':
  * `./elasticsearch-image-builder.sh`
* Check to see if it worked:
  * `docker image ls`
```shell
$ docker image ls
REPOSITORY           TAG       IMAGE ID       CREATED          SIZE
tqp-elasticsearch    7.17.0    af0b0e9d66dd   10 minutes ago   612MB
```

## Build the Kibana Image
* Modify 'kibana.yml' as needed:
  * The 'elasticsearch.username' should be 'kibana_system', by default:
    * This is a built-in username that's installed with Elasticsearch.
    * REF: https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html
  * You'll likely never actually use the 'elasticsearch.password':
    * It's only used by Kibana to communicate with Elasticsearch.
  * REF: https://www.elastic.co/guide/en/kibana/current/settings.html
  * REF: https://www.elastic.co/guide/en/kibana/current/using-kibana-with-security.html
* Modify 'kibana-dockerfile' to use the desired version of Kibana (which is the same version as Elaticsearch):
  * `FROM docker.elastic.co/kibana/kibana:7.17.0`
* Modify 'kibana-image-builder.sh' to use the desired version of Elasticsearch:
  * `ELASTICSEARCH_IMAGE_TAG=tqp1-elasticsearch:7.17.0`
* Run 'elasticsearch-image-builder.sh':
  * `./elasticsearch-image-builder.sh`
* Check to see if it worked:
  * `docker image ls`
```shell
$ docker image ls
REPOSITORY          TAG       IMAGE ID       CREATED          SIZE
tqp-kibana          7.17.0    2c25b9787179   10 minutes ago   888MB
tqp-elasticsearch   7.17.0    af0b0e9d66dd   10 minutes ago   612MB
```

## Generate Certificates
We're going to use self-signed certificates in this exercise.  
We'll use the 'elasticsearch-certutil' tool that comes with Elasticsearch.  
Since we're not running any Containers with Elasticsearch yet, we'll spin one up temporarily.
* Update 'certificate-generator-instances.yml' to include info for all the certificates you'll need:
```yaml
instances:
  - name: tqp-elasticsearch-01
    dns:
      - tqp-elasticsearch-01
      - localhost
    ip:
      - 127.0.0.1

  - name: tqp-elasticsearch-02
    dns:
      - tqp-elasticsearch-02
      - localhost
    ip:
      - 127.0.0.1

  - name: tqp-elasticsearch-03
    dns:
      - tqp-elasticsearch-03
      - localhost
    ip:
      - 127.0.0.1

  - name: tqp-kibana-01
    dns:
      - tqp-kibana-01
      - localhost
    ip:
      - 127.0.0.1
```
* Modify 'certificate-generator.yml' to use the version of Elasticsearch from the image.
  * `image: tqp-elasticsearch:7.17.0`
* Run 'certificate-generator.sh':
  * `./certificate-generator.sh`
* Check to see if it worked:
  * It should have created a 'certs' directory containing the ca and container certificates.
  * There will also be a zipped bundle with the certificates.
  * IMPORTANT: This tool does not provide the password for the ca.crt file:
    * This means that it's not possible to add more certs to the CA later on.
    * If you need to add more Containers to your Elastic cluster, you'll need to re-generate ALL the certificates.
    * That said, you could technically use the came "external" cert for all Containers and just re-generate the "internal" ones.
      * In the 'elasticsearch-docker-compose.yml' file:
        * "external" = `xpack.security.http.ssl.certificate`
        * "internal" = `xpack.security.transport.ssl.certificate`

## Start the Elastic Cluster
* Modify 'elastic-cluster-docker-compose.yml' (included in its entirety below).
  * This is a long, complex file where using environment variables could be helpful.
* Ensure that any previously-started Containers have been stopped:
  * `docker container ls`
  * `docker container stop tqp-elasticsearch-01`
  * `docker container stop tqp-elasticsearch-02`
  * `docker container stop tqp-elasticsearch-03`
  * `docker container stop tqp-kibana-01`
* Run docker-compose to start the Elastic cluster:
  * ` docker-compose -f elastic-cluster-docker-compose.yml up -d`
    * -f: use a named file, other than "docker-compose.yml".
    * -d: run in "detached" mode (i.e., in the background)
* Check to see if the four Docker Containers are running:
  * `docker ps`
```text
$ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED         STATUS                          PORTS                              NAMES
4259015a73ff   tqp-elasticsearch:7.17.0   "/bin/tini -- /usr/l…"   9 minutes ago   Up 8 minutes                    9200/tcp, 9300/tcp                 tqp-elasticsearch-03
5bfe7b3055ff   tqp-elasticsearch:7.17.0   "/bin/tini -- /usr/l…"   9 minutes ago   Up 8 minutes                    0.0.0.0:9200->9200/tcp, 9300/tcp   tqp-elasticsearch-01
b9e8b8a9449a   tqp-elasticsearch:7.17.0   "/bin/tini -- /usr/l…"   9 minutes ago   Up 8 minutes                    9200/tcp, 9300/tcp                 tqp-elasticsearch-02
e3b1c06dbb18   tqp-kibana:7.17.0          "/bin/tini -- /usr/l…"   9 minutes ago   Restarting (1) 25 seconds ago                                      tqp-kibana-03
```

## The Kibana Password Dilemna
I'm not psyched about this part. I know there's got to be a way to set the default "kibana_system" password
in the configurations above. But, I haven't been able to get them to work, so here's a workaround.
* Once the Elastic cluster is running, if you look at the logs for the Kibana Container, you'll notice the following error:
  * "Unable to retrieve version information from Elasticsearch nodes"
  * This is because Kibana is trying to connect to Elasticsearch using the password we set for it ("kibana_system"), but that's not what it is.
  * We need to change the password for "kibana_system" in Elastic to what we expect.
  * Since we can't use Kibana to do this, we'll have to use CURL. Run this command:
    * `curl -X POST --cacert ./certs/ca/ca.crt -u elastic:elastic -H "Content-Type: application/json" https://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"kibana_system\"}"`
  * I don't like it, but as soon as you do this, you'll see your Kibana logs clear the issue.
* There is another way to do this, referenced here:
  * https://www.elastic.co/guide/en/elastic-stack-get-started/7.17/get-started-docker.html
  * It says to "Run the elasticsearch-setup-passwords tool to generate passwords for all built-in users, including the kibana_system user".
  * Chris Kolodziejczyk adapted this, and I adapted it further to this command:
    * `docker exec tqp-elasticsearch-01 sh -c "bin/elasticsearch-setup-passwords auto --batch --url https://tqp-elasticsearch-01:9200" > passwords.txt; cat passwords.txt`
    * It will output a passwords.txt file with the new passwords for all built-in users. Don't lose this info!!!!
    * Also, now you'll need to update your kibana.yml file, rebuild your image, and deploy it.
    * What a pain in the butt!!

## Test Elastic and Kibana
Now that the cluster is started, let's try to access Elastic and Kibana.
### Elastic
* It can take up to a minute or two for Elastic to be ready.
* Navigate to https://localhost:9200 to access Elastic.
  * You'll be notified that "Your connection is not private" since we're using a self-signed certificate.
    * Approve this warning to proceed.
  * You'll be prompted to enter a username and password.
    * The username is "elastic".
    * The password is the "ELASTIC_PASSWORD" from our elastic-cluster-docker-compose.yml file
      * For this exercise, the password is "elastic".
    * If you see output that ends with the tagline "You know, for Search", Elastic is running properly.
### Kibana
* Navigate to https://localhost:5601 to access Kibana.
  * You'll be notified that "Your connection is not private" since we're using a self-signed certificate.
    * Approve this warning to proceed.
  * You may see a message that says "Kibana server is not ready yet".
    * This means that Kibana is running, but hasn't fully established its connection with Elastic yet.
    * For large clusters, Kibana won't be "ready" until the "active_shards_percent_as_number" is greater than 50%.
      * REF: https://localhost:9200/_cluster/health?pretty
    
## Troubleshooting
If for any reason, components in your Elastic cluster aren't running, you can try the following:
* Check the health of the Elastic cluster from a browser:
  * https://localhost:9200/_cluster/health?pretty
* Check the health of the cluster using CURL:
  * Because we're using SSL, we have to jump through a few certificate hoops here.
  * `curl -X GET --cacert ./certs/ca/ca.crt -u elastic:elastic -H "Content-Type: application/json" https://localhost:9200/_cluster/health?pretty`
* Check the Docker logs
  * For example: `docker logs -f tqp-kibana-01`
  * Or, to "tail" the last 100 lines first: `docker logs -f --tail 100 tqp-kibana-01`
* You can log into the Container directly to look for issues there:
  * `docker exec -it tqp-elasticsearch-01 bin/bash`
* You can restart a Docker Container.
  * `docker container restart tqp-kibana-01`
* Worst, worst case, you can stop all the Containers, delete the "volumes" folder, and restart everything.
  * IMPORTANT: Don't forget to delete or prune the stopped Containers. Otherwise, they may just get restarted instead of recreated.

### Common Errors Encountered
* Kibana: "Unable to retrieve version information from Elasticsearch nodes"
  * The "kibana_system" password MUST be what Elastic thinks it is. Unless you've changed this in Elastic.
    * It is set in the kibana.yml file.
    * You can change is with CURL:
      * `curl -X POST --cacert ./certs/ca/ca.crt -u elastic:elastic -H "Content-Type: application/json" https://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"kibana_system\"}"`
* On Windows-hosted Docker instances, if the Containers get stuck in a boot-loop:
  * It may be because the vm.max_map_count is not set properly.
  * Run the "windows-vm-max-map-count-fix.sh" Shell script to correct this.

## Next Level Stuff
## Create new passwords
* `docker exec tqp-elasticsearch-01 /bin/bash -c "bin/elasticsearch-setup-passwords auto --batch --url https://tqp-elasticsearch-01:9200" > passwords.txt; cat passwords.txt`
* This will output a "passwords.txt" file with the new passwords
* Remember to update the 'elastic' & 'kibana' password in the .env file!

## Key Files
### elastic-cluster-docker-compose.yml
```yaml
version: '3.5'

services:
  tqp-elasticsearch-01:
    image: tqp-elasticsearch:7.17.0
    container_name: tqp-elasticsearch-01
    hostname: tqp-elasticsearch-01
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./volumes/tqp-elasticsearch-01:/usr/share/elasticsearch/data
      - ./certs:/usr/share/elasticsearch/config/certificates
    ports:
      - 9200:9200
    environment:
      - node.name=tqp-elasticsearch-01
      - cluster.name=elasticsearch-docker-cluster
      - discovery.seed_hosts=tqp-elasticsearch-02,tqp-elasticsearch-03
      - cluster.initial_master_nodes=tqp-elasticsearch-01
      - bootstrap.memory_lock=true
      - network.host=0.0.0.0
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.license.self_generated.type=basic
      - ELASTIC_PASSWORD=elastic
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt
      - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-01/tqp-elasticsearch-01.crt
      - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-01/tqp-elasticsearch-01.key
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt
      - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-01/tqp-elasticsearch-01.crt
      - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-01/tqp-elasticsearch-01.key
    restart: always
    networks:
      - elastic

  tqp-elasticsearch-02:
    image: tqp-elasticsearch:7.17.0
    container_name: tqp-elasticsearch-02
    hostname: tqp-elasticsearch-02
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./volumes/tqp-elasticsearch-02:/usr/share/elasticsearch/data
      - ./certs:/usr/share/elasticsearch/config/certificates
    environment:
      - node.name=tqp-elasticsearch-02
      - cluster.name=elasticsearch-docker-cluster
      - discovery.seed_hosts=tqp-elasticsearch-01,tqp-elasticsearch-03
      - cluster.initial_master_nodes=tqp-elasticsearch-01
      - bootstrap.memory_lock=true
      - network.host=0.0.0.0
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.license.self_generated.type=basic
      - ELASTIC_PASSWORD=elastic
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt
      - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-02/tqp-elasticsearch-02.crt
      - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-02/tqp-elasticsearch-02.key
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt
      - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-02/tqp-elasticsearch-02.crt
      - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-02/tqp-elasticsearch-02.key
    restart: always
    networks:
      - elastic

  tqp-elasticsearch-03:
    image: tqp-elasticsearch:7.17.0
    container_name: tqp-elasticsearch-03
    hostname: tqp-elasticsearch-03
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./volumes/tqp-elasticsearch-03:/usr/share/elasticsearch/data
      - ./certs:/usr/share/elasticsearch/config/certificates
    environment:
      - node.name=tqp-elasticsearch-03
      - cluster.name=elasticsearch-docker-cluster
      - discovery.seed_hosts=tqp-elasticsearch-01,tqp-elasticsearch-02
      - cluster.initial_master_nodes=tqp-elasticsearch-01
      - bootstrap.memory_lock=true
      - network.host=0.0.0.0
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.license.self_generated.type=basic
      - ELASTIC_PASSWORD=elastic
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt
      - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-03/tqp-elasticsearch-03.crt
      - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-03/tqp-elasticsearch-03.key
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certificates/ca/ca.crt
      - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-03/tqp-elasticsearch-03.crt
      - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certificates/tqp-elasticsearch-03/tqp-elasticsearch-03.key
    restart: always
    networks:
      - elastic

  tqp-kibana-01:
    image: tqp-kibana:7.17.0
    container_name: tqp-kibana-01
    hostname: tqp-kibana-01
    volumes:
      - ./volumes/tqp-kibana-01:/usr/share/kibana/data
      - ./certs:/usr/share/elasticsearch/config/certificates
    ports:
      - 5601:5601
    environment:
      - SERVER_HOST=0.0.0.0
      - SERVER_NAME=tqp-kibana-01
      - MONITORING_ENABLED=true
      - ELASTICSEARCH_HOSTS=["https://localhost:9200"]
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=kibana_system
      - ELASTICSEARCH_SSL_VERIFICATIONMODE=none
      - XPACK_SECURITY_ENABLED=true
      - SERVER_SSL_ENABLED=true
      - SERVER_SSL_KEY=/usr/share/elasticsearch/config/certificates/tqp-kibana-01/tqp-kibana-01.key
      - SERVER_SSL_CERTIFICATE=/usr/share/elasticsearch/config/certificates/tqp-kibana-01/tqp-kibana-01.crt
      - MAP_INCLUDEELASTICMAPSSERVICE=true
    restart: always
    networks:
      - elastic

networks:
  elastic:
    driver: bridge
```

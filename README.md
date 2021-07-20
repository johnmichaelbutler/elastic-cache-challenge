- **Load Database Stored Procedure**

  The application calls a stored procedure on the database which must be created before running the application.  You will need the RDS instance hostname, the database name and the username used to connect to the database.
  You can install the procedure from the install.sql file with the following command:
  ``` psql -h <RDS_HOSTNAME> -U <DB_USER> -f install.sql <DB_NAME> ```
- **Configure Database Connection**

  You will also need to configure the application to connect to the database by editing the [`config/database.ini`](https://raw.githubusercontent.com/ACloudGuru/elastic-cache-challenge/master/config/database.ini) file.  Use the database name, username and password you created when deploying the database.
- **Configure HTTP Server**

  If you are running the application on your workstation, you can access it at http://127.0.0.1:5000.  Alternately, you can configure an HTTP server listening on the public interface as a proxy.  I've provided such a configuration for the nginx http server in [`config/nginx-app.conf`](https://raw.githubusercontent.com/ACloudGuru/elastic-cache-challenge/master/config/nginx-app.conf).

# Packages needed
- python3
- psycopg2,
- flask,
- configparser and
- Redis modules.

# Steps
1. Launch instance
2. Create three security groups
- instance SG - Open HTTP & SSH
- RDS SG - Open only to instance SG
- cache SG - Open to instance SG (port 6379)
2. Provision an RDS Postgres DB
- Create a security group before creating the RDS DB. Make the inbound rule be for postgres only from our EC2 security group
2. Update and install vim and python
  - sudo yum update -y
  <!-- sudo amazon-linux-extras install vim redis6 python3.8  -->
  - sudo amazon-linux-extras install vim python3.8 -y

3. Download venv
  pip3 install virtualenv

4. Create directory, download  and create python environment
   mkdir app
   cd app
   python3 -m virtualenv venv

5. Activate the virtual environment
  . venv/bin/activate
  Note: To deactive, run 'deactive' in the terminal

6. Install Needed pacakges
  pip3 install flask psycopg2 configparser redis # postgres
  (if this doesn't work, download psycopg2-binary)

  Note: The following is to get psql working on our instance

  <!-- sudo amazon-linux-extras enable postgresql11 -->
  sudo amazon-linux-extras install postgresql11 -y
  sudo yum install -y postgresql-server postgresql-devel
  <!-- sudo install postgresql -y -->
  sudo /usr/bin/postgresql-setup --initdb
  sudo systemctl enable postgresql
  sudo systemctl start postgresql


  To check you can connect to the database:
  psql -U rds-username -h RDS-endpoint

  Note:
  If you cannot connect to the DB or it times out, check that the security group for our RDS is properly configured to connect to the security group for our EC2 instance. set RDS instance to be available from anywhere.

7. Download the needed files from Github, unzip the files and delete the zip files
  wget https://github.com/johnmichaelbutler/elastic-cache-challenge/archive/refs/heads/master.zip
  unzip master.zip
  rm master.zip

8. Go to the config/database.ini file and add the host, database name, user and password

  To check you can connect to the database:
  psql -U rds-username -h RDS-endpoint

9. Load Database Stored Procedure
  psql -U postgres -h $PGHOST -f install.sql
10. Run the app
  Note: Ensure that the virtual environment is activated
  python app.py

  To test that the app is running properly, try curling the IP address provided from another ssh session
  curl -L http://127.0.0.1:5000/

11. If the above worked properly, let's get our total time curling the endpoint 5 times
`time (for i in {1..5}; do curl -L http://127.0.0.1:5000/;echo \n;done)`

12. Now let's set up our Redis cluster!


NOTES ON SETUP:
In this repo, the app.py file has the proper code for the file to work the first time.
The Redis file that works is app-1.py.

# Set up redis cluster
1. Go to VPC and create a cache SG
2. Add an inbound rule and change the port range to 6379. Set the source as the security group for our ec2 instance
3. Go to ElastiCache > Create new cluster
- Cluster engine: Redis
- Name: Cache
- Description: Cache aside for app
- Node type: t2 > cache.t2.micro
- Number of replicas: 1
- Advanced settings (Subnet group > Create one)
- - Name: Cache
- - Description: cache subnet group
- - Subnets: Select two subnets in different AZs
- Security
- - Change the security group to the one we created
- Backup
- - Enable backup: Uncheck

4. Check to see if we can connect to our Redis cluster. To check, start a python console session within our venv. Run:
```
import redis
client = redis.Redis.from_url('redis://<endpoint>')
client.ping()
```
We should receive a response from our redis endpoint

# Update our App to use Redis
1. Within our app, edit our app.py file with the below information.
```
import redis

....


def fetch(sql):
    ttl = 10 # Time to live in seconds
    try:
       params = config(section='redis')
       cache = redis.Redis.from_url(params['redis_url'])
       result = cache.get(sql)

       if result:
         return result
       else:
         # connect to database listed in database.ini
         conn = connect()
         cur = conn.cursor()
         cur.execute(sql)
         # fetch one row
         result = cur.fetchone()
         print('Closing connection to database...')
         cur.close()
         conn.close()

         # cache result
         cache.setex(sql, ttl, ''.join(result))
         return result

    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
```
2. Add our Redis information to our `database.ini` config file.
```
vim database.ini
[redis]
redis_url=redis://<redis endpoint>
```
3. Run the app again and test to see if we can ping our endpoint
`curl http://127.0.0.1:5000/`

4. If it works, run the following command to see how long it takes to curl our endpoint 5 times
`time (for i in {1..5}; do curl -L http://127.0.0.1:5000/;echo \n;done)`





** SKIPPED** I was unable to setup nginx configuration. Decided to skip since it wasn't the focus of the project
11. Setting up nginx to access the flask project
  sudo amazon-linux-extras install nginx1
  sudo amazon-linux-extras install nginx1
  sudo chmod -R 755 /home/app
  sudo chown -R ec2-user:nginx /home/app
  <!-- Copes the original config file  -->
  sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf-orig

        sudo cp app_config_file /etc/nginx/conf.d/nginx-app.conf
        sudo systemctl start nginx
        sudo systemctl enable nginx

  <!-- Nginx config file needs to be  -->

# How to test database connection
  To check you can connect to the database:
  psql -U rds-username -h RDS-endpoint



https://vishnut.me/blog/ec2-flask-apache-setup.html



# Reference to isntall PSQL client on EC2 instance - Great reference
https://dailyscrawl.com/how-to-install-postgresql-on-amazon-linux-2/

# Link to Hands On Lab
https://learn.acloud.guru/handson/27f2d63d-267a-4886-be7a-e8981019e7ce


import psycopg2
from configparser import ConfigParser
from flask import Flask, request, render_template, g, abort
import time
import redis

def config(filename='config/database.ini', section='postgresql'):
    # create a parser
    parser = ConfigParser()
    # read config file
    parser.read(filename)

    # get section, default to postgresql
    db = {}
    if parser.has_section(section):
        params = parser.items(section)
        for param in params:
            db[param[0]] = param[1]
    else:
        raise Exception('Section {0} not found in the {1} file'.format(section, filename))

    return db

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
        print('Error in fetch()')
        print(error)
        return error

def connect():
    """ Connect to the PostgreSQL database server and return a cursor """
    conn = None
    try:
        # read connection parameters
        params = config()

        # connect to the PostgreSQL server
        print('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**params)


    except (Exception, psycopg2.DatabaseError) as error:
        print("Error:", error)
        conn = None

    else:
        # return a conn
        return conn

app = Flask(__name__)

@app.route("/")
def index():
    sql = 'SELECT slow_version();'
    db_result = fetch(sql)

    params = config()
    return render_template('index.html', db_version = db_result, db_host = params['host'])

if __name__ == "__main__":        # on running python app.py
    app.run()                     # run the flask app

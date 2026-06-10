from flask import Flask, jsonify
import pymysql
import os

app = Flask(__name__)

DB_HOST = os.environ.get("APP_DB_HOST", "localhost")
DB_NAME = os.environ.get("APP_DB_NAME", "appdb")
DB_USER = os.environ.get("APP_DB_USER", "appuser")
DB_PASSWORD = os.environ.get("APP_DB_PASSWORD", "apppassword")


@app.route("/")
def home():
    return """
    <html>
      <head>
        <title>Ansible Python App</title>
      </head>
      <body>
        <h1>Ansible Python App läuft</h1>
        <p>Diese Flask-App wurde automatisch mit Ansible deployed.</p>
        <ul>
          <li><a href="/health">Health Check</a></li>
          <li><a href="/db">Database Check</a></li>
        </ul>
      </body>
    </html>
    """


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "service": "python-app"
    })


@app.route("/db")
def db_check():
    try:
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=5
        )

        with connection.cursor() as cursor:
            cursor.execute("SELECT DATABASE();")
            result = cursor.fetchone()

        connection.close()

        return jsonify({
            "status": "ok",
            "database": result[0],
            "db_host": DB_HOST
        })

    except Exception as error:
        return jsonify({
            "status": "error",
            "message": str(error),
            "db_host": DB_HOST
        }), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
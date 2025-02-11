import os
import socket
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    environment = os.getenv("STAGE_ENVIRONMENT")
    hostname = socket.gethostname()
    pod_ip = socket.gethostbyname(hostname)

    return f"""
    <html>
    <head><title>Deployment Info</title></head>
    <body>
        <h1>Environment             : <b>{environment}</h1>
        <h2>This is image version   : </b>1.0.0</h2>
        <p><b>Pod Name              : </b>{hostname}</p>
        <p><b>Pod IP                : </b>{pod_ip}</p>
    </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)

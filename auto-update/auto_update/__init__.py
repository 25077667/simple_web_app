from flask import Flask, Blueprint
from update import Update

app = Flask(__name__)
app.register_blueprint(Update, url_prefix='/update')


@app.route("/ping")
def ping():
    return "pong!"


def main():
    app.run('localhost', 8080)


if __name__ == "__main__":
    main()

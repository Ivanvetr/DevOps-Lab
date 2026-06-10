from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def home():
    return jsonify({
        "mensaje": "API DevOps Lab funcionando",
        "version": "1.0.0",
        "estado": "ok"
    })


@app.route("/salud")
def salud():
    return jsonify({"estado": "saludable"}), 200


@app.route("/suma/<int:a>/<int:b>")
def suma(a, b):
    return jsonify({"resultado": a + b})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

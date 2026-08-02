'''
Author: LetMeFly
Date: 2026-08-02 10:21:42
LastEditors: LetMeFly.xyz
LastEditTime: 2026-08-02 10:47:52
'''

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs


class CallbackHandler(BaseHTTPRequestHandler):

    def do_POST(self):

        length = int(self.headers.get("Content-Length", 0))

        body = self.rfile.read(length).decode()

        print("callback body:")
        print(body)


        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, "invalid JSON")
            return


        # 校验
        if data.get("req_id") != self.server.req_id:
            self.send_error(403, "bad req_id")
            return


        if data.get("token") != self.server.token:
            self.send_error(403, "bad token")
            return


        print("callback verified")

        self.server.result = data


        self.send_response(200)
        self.end_headers()

        self.wfile.write(b"ok")

        # 停止 server
        self.server.shutdown()



def wait_callback(port, req_id, token):

    server = ThreadingHTTPServer(
        ("0.0.0.0", port),
        CallbackHandler
    )

    server.req_id = req_id
    server.token = token
    server.result = None


    print(f"listen :{port}")

    server.serve_forever()

    return server.result



if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument("--port", type=int, default=8759)
    parser.add_argument("--req-id", required=True)
    parser.add_argument("--token", required=True)

    args = parser.parse_args()


    result = wait_callback(
        args.port,
        args.req_id,
        args.token
    )


    print(json.dumps(result))
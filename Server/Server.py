from bottle import route, run, request, HTTPResponse
import json

@route('/api/location', method='POST')
def POST_Locatin():
    print(request.json)
    r = HTTPResponse(status=200, body=json.dumps({'status': 'ok'}))

    return r


run(host='192.168.1.233', port=8080)

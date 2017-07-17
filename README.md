# IT-Service Notification microservice

This microservice is a part of IT-Service application, which powers IT-Premium business. 

Purpose of this microservice is to serve some of the internal system events, like the ticket expiration, ticket assignment, etc.
to be delivered to the clients browser in realtime. This service subscribes to queue via redis channels and do notification push via [Server Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events).

Built and deployed with Docker.

Stack:
  - Sinatra + Thin
  - [sinatra-sse](https://github.com/radiospiel/sinatra-sse)
  - Redis
  - Sequel

## INSTALLATION

     docker build .

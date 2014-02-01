package main

import (
	"net/http"
	"flag"
)

var addr string

func init() {
	flag.StringVar(&addr, "addr", ":8080", "address to listen on")
	flag.Parse()
}

func main() {
	println("Starting server:", addr)
	http.ListenAndServe(addr, http.FileServer(http.Dir("build")))
}

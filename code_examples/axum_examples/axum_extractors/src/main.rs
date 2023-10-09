use std::collections::HashMap;

use axum::{extract::Query, routing::get, Router};

#[tokio::main]
async fn main() {
    // build our application with a single route
    let app = Router::new().route("/", get(print_hello));

    // run it with hyper on localhost:3000
    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn print_hello(Query(query): Query<HashMap<String, String>>) -> String {
    let hello = query.get("foo").unwrap();
    let world = query.get("baz").unwrap();
    let hello_world = format!("{} {}", hello, world);
    hello_world
}

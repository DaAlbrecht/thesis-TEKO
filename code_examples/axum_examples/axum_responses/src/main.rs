use axum::{http::StatusCode, response::IntoResponse, routing::get, Json, Router};

#[derive(serde::Serialize)]
struct User {
    name: String,
    age: u8,
}

#[tokio::main]
async fn main() {
    // build our application with a single route
    let app = Router::new()
        .route("/", get(print_hello))
        .route("/user", get(print_user));

    // run it with hyper on localhost:3000
    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn print_hello() -> &'static str {
    "Hello, World!"
}

async fn print_user() -> impl IntoResponse {
    (
        StatusCode::OK,
        Json(User {
            name: "Bob".to_string(),
            age: 20,
        }),
    )
}

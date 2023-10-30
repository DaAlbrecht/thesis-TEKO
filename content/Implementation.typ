#import "@preview/tablex:0.0.5": tablex, cellx
#import "@preview/codelst:1.0.0": sourcecode
#show figure.where(kind: raw): set block(breakable: true)

The entire project is available on #link("https://github.com/DaAlbrecht/rabbit-revival/tree/main")[GitHub] and
licensed under the MIT license. For a clearer understanding and reasoning of the
design decisions, the code is documented inline with syntax highlighting and a
short description to each snippet is provided. 

== Prerequisites

For the development of the replay microservice, the following tools are required:

#figure(
  tablex(
    columns: (auto,1fr,auto),
    rows:(auto),
    align: (center + horizon, left, left),
    [*Name*],
    [*Description*],
    [*Install*],
    [Rust],
    [The microservice is written in Rust. The Rust toolchain is required to build the microservice.],
    [#link("https://www.rust-lang.org/tools/install")],
    [Docker],
    [The microservice aswell as RabbitMQ are run in docker containers.],
    [#link("https://docs.docker.com/get-docker/")],
    [RabbitMQ],
    [The microservice uses RabbitMQ as a message broker.],
    [The container can be started as shown in @api-lib-setup],
    [curl],
    [The microservice can be tested using curl.],
    [#link("https://curl.se/download.html")],
    ),
    kind: table,
    caption: [development prerequisites]
  )

  == Project setup 

  The replay microservice Rust project was created, and as a development name the name "rabbit-revival" was chosen. The project is created using the following command:

#figure(sourcecode(numbering: none)[```bash
  cargo new rabbit-revival
  cd rabbit-revival
  ```], caption: [create project])

 Rust does not provide a large standard library, instead, it relies on third-party
crates for many basic functionalities. Based on the @architecture axum is used
as a web framework, Tokio is used for asynchronous runtime  and lapin is used
as a RabbitMQ client. The dependencies and other commonly used crates are added to the Cargo.toml file:

#figure(sourcecode(numbering: none)[```bash 
cargo add tokio --features full
cargo add axum
cargo add lapin
cargo add serde --features derive
cargo add serde_json
cargo add anyhow
```], caption: [common  dependencies])

#figure(
  tablex(
    columns: (auto,1fr),
    rows:(auto),
    align: (center + horizon, left),
    [*Name*],
    [*Description*],
    [Tokio],
    [Tokio is an asynchronous runtime],
    [axum],
    [axum is a web framework created by the tokio team],
    [lapin],
    [lapin is a RabbitMQ client],
    [Serde],
    [Serde is a serialization / deserialization framework],
    [Serde_json],
    [Serde json is a Serde implementation for json],
    [anyhow],
    [anyhow is a crate for easy error handling],
    ),
    kind: table,
    caption: [overview of commonly used crates]
)

With the basic project setup done, the first task is to implement the web service according to the OpenAPI specification from  @openapi_specification

 == Webservice

In order to understand the implementation of the replay microservice, first some basic concepts of axum are explained.

=== axum concepts

Axum uses tower#footnote("https://docs.rs/tower/latest/tower/index.html") under the hood. Tower is a high-level abstraction for
networking applications. The basic idea is that a trait #footnote("https://doc.rust-lang.org/book/ch10-02-traits.html") called
`Serivce` exists. This service receives a request and returns either a response or
an error.
#figure(
sourcecode()[```rust
pub trait Service<Request> {

    fn poll_ready(&mut self,cx: &mut Context<'_>) ->
    Poll<Result<(), Self::Error>>;

    fn call(&mut self, req: Request) -> Self::Future;
}
```],
caption: [stripped down tower service trait]
)
Since a `Service` is generic, any middleware that also implements the `Service`
trait can be used allowing axum to use a large ecosystem of middleware.

Axum like any other web sever needs to be able to handle multiple requests concurrently, making a web server
inherently asynchronous. 

  #figure(
  sourcecode()[```rust
use axum::{routing::get, Router};
#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(print_hello));
    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
  ```,],
  caption: [axum routing]
  )

Rust uses colored functions#footnote(
  "https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/",
) and therefore, functions that call asynchronous functions need to be marked as
asynchronous as well. Since Rust does not provide an asynchronous runtime it's not
possible to declare the main entrypoint with the `async` keyword. Tokio uses the
macro `#[tokio::main]` to allow specifying the main function as asynchronous.#footnote("https://tokio.rs/tokio/tutorial/hello-tokio")
without needing to use the runtime or builder directly.

The macro transforms the main function into the following code: 

#figure(
sourcecode()[```rust
fn main() {
    let mut rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
      let app = Router::new().route("/", get(print_hello));

      axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
          .serve(app.into_make_service())
          .await
          .unwrap();
        })
}
```],
)

The main function handles the creation of the axum server and starts the server.

In axum, the routing is handled by the `Router` struct. The `Router` matches request paths to Rust functions called `Handlers` based on the HTTP method filter.

#figure(
sourcecode()[```rust
let app = Router::new()
      .route("/", get(print_hello));
```],
caption: [routing]
)

Afterwards, the server is bound to a socket address and the server is started
with the `serve` method. The `serve` method consumes an object that can be
turned into a service and transforms it into a service.

#figure(
sourcecode()[```rust
axum::Server::bind(&addr)
    .serve(app.into_make_service())
    .await
    .unwrap();
  })
```],
caption: [starting the server]
)

#pagebreak()

To better visualize the relationship between a service and a handler the
the following program is used to demonstrate their purpose.

#figure(
sourcecode()[```rust
use axum::{routing::get, Router};

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

async fn print_hello() -> &'static str {
    "Hello, World!"
}
```],
caption: [hello world example]
)<hello_world_example>

The router is created with a single route that matches the path `/` and the
method `GET`. If a request is received that matches the route of the HTTP method,
the function `print_hello` is called. The function returns a string that is
converted into a response by axum. The response is then sent to the client.

#sourcecode(numbering: none)[```bash
cargo run
curl 'localhost:3000'
> hello world
```]

In the example above the `print_hello` handler takes no arguments and just returns
a static string. In the OpenAPI specification, the replay microservice needs to be able to 
receive query parameters or a JSON body. 
#linebreak()

In axum there are `Extractors`. Extractors are used to extract data from the request.
An Extract implements *either* the `FromRequest` or the `FromRequestParts` trait.
The difference between the two is, that the `FromRequest` consumes the request body
and thus can only be used once. The `FromRequestParts` trait does not consume the
request body and can be used multiple times. 

#pagebreak()

So if we consider the following modified hello world example:

#figure(
sourcecode()[```rust
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
```],
caption: [extracting query parameters]
)<extraxting_query_parameters>

The handler `print_hello` takes an extractor as an argument. The extractor `Query`
extractor implements the `FromRequestParts` trait. The `Query` extractor deserializes
the query parameters into some type that implements `Deserialize`. In this case,
the query parameters are deserialized into a `HashMap<String, String>`.

#sourcecode(numbering: none)[```bash
curl 'localhost:3000?foo=hello&baz=world'
> hello world
```]

So to recap, a `Handler` is a function that takes zero or more `Extractors` as arguments and returns something
that can be turned into a `Response`.
#linebreak()

A `Response` is every type that implements the `IntoResponse` trait. axum implements
the trait for many common types like `String`, `&str`, `Vec<u8>`, `Json`, and many more.
#pagebreak()
But the real magic of axum is the demonstrate in the next examples.

#figure(
sourcecode()[```rust
use axum::{http::StatusCode, response::IntoResponse, routing::get, Json, Router};

#[derive(serde::Serialize)]
struct User {
    name: String,
    age: u8,
}

#[tokio::main]
async fn main() {
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
```],
caption: [IntoResponse]
)<IntoResponse>

#sourcecode(numbering: none)[```bash
curl -v 'localhost:3000/user'
*   Trying 127.0.0.1:3000...
* Connected to localhost (127.0.0.1) port 3000 (#0)
> GET /user HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/8.1.2
> Accept: */*
>
< HTTP/1.1 200 OK
< content-type: application/json
< content-length: 23
< date: Mon, 09 Oct 2023 13:21:21 GMT
<
* Connection #0 to host localhost left intact
{"name":"Bob","age":20}
```]

A new custom type called `User` is created. The crate `serde` is used to derive
the `Serialize` trait for the `User` struct. Deriving in that sense means that
the trait gets automatically implemented for the struct.

The important part is that as stated earlier, a handler returns something that
can be turned into a `Response`. We can use this fact and, instead of returning a concrete
type like `String` or `&str` we can tell the compiler that the handler returns
something that implements the `IntoResponse` trait with the following line:

#sourcecode(numbering: none)[```rust
async fn print_user() -> impl IntoResponse
```]

But how does our own custom type `User` implement the `IntoResponse` trait? The
answer and beautiful part of axum is that it does  not. Instead axum uses macros#footnote("https://doc.rust-lang.org/book/ch19-06-macros.html")
to automatically implement the `IntoResponse` trait for tuples of different
sizes.

In the documentation of axum @docrs_into_response its visible that the trait is implemented for tuples of size 0 to 16.

If we look at an example of the implementation of the trait a pattern is visible.
#figure(
image("../assets/into_response.png"),
caption: [IntoResponse implementations]
)

The implementation of the trait is generic over the types `T` and `R`.  Any tuple 
from size 0 to 16 can be turned into a response *iff* the last element of the tuple 
implements the `IntoResponse` trait and the other elements implement the `IntoResponseParts` trait.

The `IntoResponseParts` trait is used to add headers to the response while the 
`IntoResponse` trait is used generate the response.

There are other automatic implementations of the `IntoResponse` trait that follow 
a similar pattern. 

#figure(
image("../assets/into_response_status_code.png"),
caption: [IntoResponse implementations]
)

For example, tuples of size 0 to 16 where the first element 
implements the `StatusCode` and just like before, the last element implements the 
`IntoResponse` trait while the other elements implement the `IntoResponseParts` trait.



So in conclusion, axum uses a router to match requests to handlers. `Handlers`
are functions that take zero or more `Extractors` as arguments and return
something that can be turned into a `Response`.With the help of `Extractors` and
`Responses` axum ensures runtime type safety. A `Response` is every type that
implements the `IntoResponse` trait. The `IntoResponse` trait is automatically
implemented for commonly used types aswell as different sized tuples. It is also
possible to implement the trait manually for specific use cases.

Let's check the return value from the example shown in  @IntoResponse again:

#sourcecode(numbering: none)[```rust 
(
    StatusCode::OK,
    Json(User {
        name: "Bob".to_string(),
        age: 20,
    }),
)
```]

In the example above the return value is a tuple of size 2. According to the 
documentation the following implementation should fit 

#sourcecode(numbering: none)[```rust 
impl<R> IntoResponse for (StatusCode, R)
where
    R: IntoResponse,
```]

The first element of the tuple is a `StatusCode`, so this is correct. And the 
second element of the tuple is a `Json<User>`. In the documentation of `axum::Json`,
the following implementation is shown:

#sourcecode(numbering: none)[```rust 
impl<T> IntoResponse for Json<T>
where
    T: Serialize,
```]

The `User` struct implements the `Serialize` trait, allowing Serde to represent the struct as JSON, so this is correct and the Return value
indeed implements the `IntoResponse` trait.
#linebreak()
This allows us to model the OpenAPI specification as Rust struct's using them either as return type or as extractor and letting Serde take care of the serialization and deserialization.

#pagebreak()

=== Implementation 

The main function is responsible for composing and starting the server.

#figure(
  sourcecode()[```rust 
#[tokio::main]
async fn main() {
  // initialize tracing
  tracing_subscriber::registry()
      .with(
          tracing_subscriber::EnvFilter::try_from_default_env()
          .unwrap_or_else(|_| {
              "rabbit_revival=debug,tower_http=trace,axum::rejection=trace"
              .into()
          }),
      )
      .with(tracing_subscriber::fmt::layer())
      .init();

  let app = Router::new()
      .route("/replay", get(get_messages).post(replay))
      .layer(TraceLayer::new_for_http())
      .with_state(initialize_state().await);

  let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

  tracing::info!("Listening on {}", addr);
  axum::Server::bind(&addr)
      .serve(app.into_make_service())
      .await
      .unwrap();
}
```],
caption: [main function]
)

The main function is marked as asynchronous using the `#[tokio::main]` macro.
#linebreak()

Tracing has been identified as an essential use case, thus the first thing the main function does is initialize tracing. Tracing is a
framework for instrumenting Rust programs with structured logging and diagnostics.
Tracing is provided by the crate `tracing`#footnote("https://docs.rs/tracing/latest/tracing/") and `tracing-subscriber`#footnote("https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/"). 

#figure(
  sourcecode()[```rust 
tracing_subscriber::registry()
    .with(
        tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| {
            "rabbit_revival=debug,tower_http=trace,axum::rejection=trace"
            .into()
        }),
    )
    .with(tracing_subscriber::fmt::layer())
    .init();
```],
caption: [tracing initialization]
)

The tracing subscriber is initialized by the default
environment variable `RUST_LOG` or set to the provided default value.
#linebreak()

Afterwards, an axum router is created.

#figure(
  sourcecode()[```rust 
let app = Router::new()
    .route("/replay", get(get_messages).post(replay))
    .layer(TraceLayer::new_for_http())
    .with_state(initialize_state().await);
```],
caption: [axum router]
)

The router is created with one route that matches the path `/replay`. 
The route has two `MethodFilter`s attached to it. The first filter matches the 
`GET` method and the second filter matches the `POST` method. The `GET` method 
is handled by the `get_messages` handler and the `POST` method is handled by the 
`replay` handler.

The feature `tracing`#footnote("https://docs.rs/axum/0.6.20/axum/index.html#feature-flags") is
enabled for axum. Tower services can be composed using the `Layer` trait.
Tracing is added as middleware to the router using the `layer` method.
Additionally, some state needs to be shared between handlers and therefore the 
`with_state` method is used to add the state to the router.
The state is initialized using the `initialize_state` function.

#figure(
  sourcecode()[```rust 
async fn initialize_state() -> Arc<AppState> {
  let pool_size = std::env::var("AMQP_CONNECTION_POOL_SIZE")
      .unwrap_or("5".into())
      .parse::<usize>()
      .unwrap();

  let username = std::env::var("AMQP_USERNAME").unwrap_or("guest".into());
  let password = std::env::var("AMQP_PASSWORD").unwrap_or("guest".into());
  let host = std::env::var("AMQP_HOST").unwrap_or("localhost".into());
  let amqp_port = std::env::var("AMQP_PORT").unwrap_or("5672".into());
  let management_port = std::env::var("AMQP_MANAGEMENT_PORT").unwrap_or("15672".into());

  let transaction_header = std::env::var("AMQP_TRANSACTION_HEADER")
      .ok()
      .filter(|s| !s.is_empty());

  let enable_timestamp = std::env::var("AMQP_ENABLE_TIMESTAMP")
      .unwrap_or("true".into())
      .parse::<bool>()
      .unwrap();

  let publish_options = MessageOptions {
      transaction_header,
      enable_timestamp,
  };

  let amqp_config = RabbitmqApiConfig {
      username: username.clone(),
      password: password.clone(),
      host: host.clone(),
      port: management_port.clone(),
  };

  let mut cfg = Config::default();
  cfg.url = Some(format!(
      "amqp://{}:{}@{}:{}/%2f",
      username, password, host, amqp_port
  ));

  cfg.pool = Some(PoolConfig::new(pool_size));

  let pool = cfg.create_pool(Some(Runtime::Tokio1)).unwrap();

  Arc::new(AppState {
      pool,
      message_options: publish_options,
      amqp_config,
  })
}
```],
caption: [initialize state]
)

The function is marked as asynchronous using the `async` keyword and returns an
`Arc<AppState>`. 

#sourcecode(numbering: none)[```rust 
async fn initialize_state() -> Arc<AppState>
```]

`Arc` is an abbreviation for atomic reference counter. The `Arc` type allows
multiple ownership of the same data while ensuring thread safety. The `Arc` type
is used to share the state between handlers.

`AppState` is custom struct that holds the state of the application.

#figure(
  sourcecode()[```rust 
  struct AppState {
    pool: deadpool_lapin::Pool,
    message_options: MessageOptions,
    amqp_config: RabbitmqApiConfig,
}
```],
caption: [AppState]
)

The struct holds a pool of amqp connections, its recommended to use long-lived
connections to amqp and create separate channels for each thread. The other fields
hold a struct `MessageOptions` and a  struct `RabbitmqApiConfig`.

#figure(
  sourcecode()[```rust 
#[derive(Clone)]
pub struct MessageOptions {
    transaction_header: Option<String>,
    enable_timestamp: bool,
}
```],
caption: [MessageOptions]
)<MessageOptions>

When replaying a message from the stream, the message gets published again. The
API supports adding a uid to a custom header. Additionally, the API supports adding a timestamp to the message. Both options are configurable using environment
variables and are optional.

#figure(
  sourcecode()[```rust
#[derive(Debug)]
pub struct RabbitmqApiConfig {
    username: String,
    password: String,
    host: String,
    port: String,
}
```],
caption: [RabbitmqApiConfig]
)

The `RabbitmqApiConfig` struct holds the configuration for the RabbitMQ
management API. The AMQP protocol lacks a way to query the state of a queue. To
acquire the metadata of a queue the RabbitMQ management API is used.

#linebreak()

First, in the `initialize_state` function the environment variables are read.

#figure(
  sourcecode()[```rust 
let pool_size = std::env::var("AMQP_CONNECTION_POOL_SIZE")
      .unwrap_or("5".into())
      .parse::<usize>()
      .unwrap();

let username = std::env::var("AMQP_USERNAME").unwrap_or("guest".into());
let password = std::env::var("AMQP_PASSWORD").unwrap_or("guest".into());
let host = std::env::var("AMQP_HOST").unwrap_or("localhost".into());
let amqp_port = std::env::var("AMQP_PORT").unwrap_or("5672".into());
let management_port = std::env::var("AMQP_MANAGEMENT_PORT").unwrap_or("15672".into());

let transaction_header = std::env::var("AMQP_TRANSACTION_HEADER")
    .ok()
    .filter(|s| !s.is_empty());

let enable_timestamp = std::env::var("AMQP_ENABLE_TIMESTAMP")
    .unwrap_or("true".into())
    .parse::<bool>()
    .unwrap();
```],
caption: [read environment variables]
)

Each environment variable is read and if the variable is not set a default value
is provided.
#linebreak()

Afterward, the three structs, required to initialize the state are created.

#figure(
  sourcecode()[```rust 
let publish_options = MessageOptions {
    transaction_header,
    enable_timestamp,
};

let amqp_config = RabbitmqApiConfig {
    username: username.clone(),
    password: password.clone(),
    host: host.clone(),
    port: management_port.clone(),
};

let mut cfg = Config::default();
cfg.url = Some(format!(
    "amqp://{}:{}@{}:{}/%2f",
    username, password, host, amqp_port
));

cfg.pool = Some(PoolConfig::new(pool_size));

let pool = cfg.create_pool(Some(Runtime::Tokio1)).unwrap();
```],
caption: [create required AppState structs]
)

A new `Arc<AppState>` is created and returned.

#figure(
  sourcecode()[```rust 
Arc::new(AppState {
  pool,
  message_options: publish_options,
  amqp_config,
})
```],
caption: [return AppState]
)

After the router is created, the server is bound to the socket address
`127.0.0.1:3000` and the server is started.

#figure(
  sourcecode()[```rust 
let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

tracing::info!("Listening on {}", addr);
axum::Server::bind(&addr)
    .serve(app.into_make_service())
    .await
    .unwrap();
```],
caption: [starting the server]
)

The `get_messages` handler allows to get information about queues and messages

#figure(
  sourcecode()[```rust 
async fn get_messages(
  app_state: State<Arc<AppState>>,
  Query(message_query): Query<MessageQuery>,
) -> Result<impl IntoResponse, AppError> {
  let messages = fetch_messages(
      &app_state.pool.clone(),
      &app_state.amqp_config,
      &app_state.message_options,
      message_query,
  )
  .await?;
  Ok((StatusCode::OK, Json(messages)))
}
```],
caption: [get_messages handler]
)

The handler takes two arguments. The first argument is the application state,
the second argument is an extractor. The extractor is used to extract the query 
parameters from the request. The query parameters are deserialized into a struct 
called `MessageQuery`.

#figure(
  sourcecode()[```rust 
#[derive(serde::Deserialize, Debug)]
pub struct MessageQuery {
    queue: String,
    from: Option<DateTime<chrono::Utc>>,
    to: Option<DateTime<chrono::Utc>>,
}
```],
caption: [MessageQuery]
)

The `MessageQuery` struct holds the query parameters. The `queue` parameter is
required and the `from` and `to` parameters are optional. The `from` and `to`
parameters are used to filter the messages by their timestamp. 

Axum does the deserialization of the query parameters automatically and ensures
runtime type safety. If the query parameters are not valid, axum returns a sane 
default error message.

#sourcecode(numbering: none)[```bash 
curl 'localhost:3000/?hello=replay'
>Failed to deserialize query string: missing field `queue`
curl 'localhost:3000/?queue=foo&from=123'
>Failed to deserialize query string: premature end of input
curl 'localhost:3000/?queue=foo&from=bar'
>Failed to deserialize query string: input contains invalid characters
```]

The handler returns a ```rust Result<impl IntoResponse, AppError>```. 
By returning a Result, the handlers can be written in a more idiomatic way and 
take advantage of the `?` operator. The `?` operator is used to propagate errors.

Axum does not know how to turn an `AppError` into a response. In
the axum examples#footnote("https://github.com/tokio-rs/axum/tree/axum-0.6.21/examples") 
there is an example, on how to use the `anyhow` crate#footnote("https://docs.rs/anyhow/1.0.40/anyhow/") 
to handle errors.

#linebreak()

In order to tell axum how to turn an `AppError` into a response, the `IntoResponse`
trait needs to be implemented for the `AppError` type.

#figure(
  sourcecode()[```rust 
//https://github.com/tokio-rs/axum/blob/main/examples/anyhow-error-response/src/main.rs
// Make our own error that wraps `anyhow::Error`.
struct AppError(anyhow::Error);

// Tell axum how to convert `AppError` into a response.
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("Something went wrong: {}", self.0),
        )
            .into_response()
    }
}

// This enables using `?` on functions that return `Result<_, anyhow::Error>` to turn them into
// `Result<_, AppError>`. That way you don't need to do that manually.
impl<E> From<E> for AppError
where
    E: Into<anyhow::Error>,
{
    fn from(err: E) -> Self {
        Self(err.into())
    }
}
```],
caption: [AppError]
)

The `get_messages` handler calls the function `fetch_messages`, awaits the future 
and messages in a JSON format as well as a status code.

#figure(
  sourcecode()[```rust 
let messages = fetch_messages(
    &app_state.pool.clone(),
    &app_state.amqp_config,
    &app_state.message_options,
    message_query,
)
.await?;
Ok((StatusCode::OK, Json(messages)))
```],
caption: [get_messages function body]
)

The `fetch_messages` function is responsible for fetching the messages from the Queue and is shown in @fetch_messages.
#linebreak()

The other handler is the `replay` handler. The `replay` handler is responsible for 
replaying messages from the stream.

#figure(
  sourcecode()[```rust 
async fn replay(
    app_state: State<Arc<AppState>>,
    Json(replay_mode): Json<ReplayMode>,
) -> Result<impl IntoResponse, AppError> {
  let pool = app_state.pool.clone();
  let message_options = app_state.message_options.clone();
  let messages = match replay_mode {
      ReplayMode::TimeFrameReplay(timeframe) => {
          replay_time_frame(&pool, &app_state.amqp_config, timeframe).await?
      }
      ReplayMode::HeaderReplay(header) => {
          replay_header(&pool, &app_state.amqp_config, header).await?
      }
  };
  let replayed_messages = replay::publish_message(&pool, &message_options, messages).await?;
  Ok((StatusCode::OK, Json(replayed_messages)))
}
```],
caption: [replay handler]
)

According to the OpenAPI specification from the microservice shown in @openapi_specification,
the POST method supports two different kinds of schema.
#linebreak()

To represent the two different kinds of schema, an enum is used.

#figure(
  sourcecode()[```rust 
#[derive(serde::Deserialize, Debug)]
#[serde(untagged)]
enum ReplayMode {
    TimeFrameReplay(TimeFrameReplay),
    HeaderReplay(HeaderReplay),
}
```],
caption: [ReplayMode]
)

The enum holds two variants representing the two different kinds of schema.
#linebreak()

The first variant is called `TimeFrameReplay` and requires the name of the `queue`
and a `from` and `to` parameter. The `from` and `to` parameters are used to filter
the messages by their timestamp.

#figure(
  sourcecode()[```rust 
#[derive(serde::Deserialize, Debug)]
pub struct TimeFrameReplay {
    queue: String,
    from: DateTime<chrono::Utc>,
    to: DateTime<chrono::Utc>,
}
```],
caption: [TimeFrameReplay]
)

The second variant is called `HeaderReplay` and requires the name of the `queue`
and the header that should be replayed.

#figure(
  sourcecode()[```rust
#[derive(serde::Deserialize, Debug)]
pub struct HeaderReplay {
    queue: String,
    header: AMQPHeader,
}
```],
caption: [HeaderReplay]
)

#figure(
  sourcecode()[```rust
#[derive(serde::Deserialize, Debug)]
struct AMQPHeader {
    name: String,
    value: String,
}
```],
caption: [AMQPHeader]
)

The enum is annotated with `#[serde(untagged)]`. 
#linebreak()
The `#[serde(untagged)]` attribute is used to tell Serde to not explicitly identify
one of the variants of the enum. Instead, Serde tries to deserialize the JSON into 
each variant in order and returns the first variant that succeeds.

#pagebreak()
Without the `#[serde(untagged)]` attribute, the following JSON body representing a time-based replay would be invalid.

#sourcecode(numbering: none)[```json 
{
  "queue":"replay",
  "from":"2023-10-06T13:41:35.870Z",
  "to":"2023-10-09T13:41:35.883Z"
}
```]

Instead, the JSON body would need to look like this:

#sourcecode(numbering: none)[```json 
{
  "TimeFrameReplay": {
    "queue":"replay",
    "from":"2023-10-06T13:41:35.870Z",
    "to":"2023-10-09T13:41:35.883Z"
  }
}
```]


Similarly to the `get_messages` handler, the `replay` handler takes two arguments.
The first argument is the application state and the second argument is an extractor.
The extractor is used to extract the JSON body from the request. The JSON body is
serialized into the `ReplayMode` enum.

#sourcecode(numbering: none)[```rust 
async fn replay(
  app_state: State<Arc<AppState>>,
  Json(replay_mode): Json<ReplayMode>,
) -> Result<impl IntoResponse, AppError> {
```]

The `replay` handler just like the `get_messages` handler returns a ```rust
Result<impl IntoResponse, AppError>```

In the function body serialized JSON body is matched against the two variants of
the `ReplayMode` enum. Depending on the variant, the `replay_time_frame` or the
`replay_header` function is called.

#figure(
  sourcecode()[```rs
let messages = match replay_mode {
  ReplayMode::TimeFrameReplay(timeframe) => {
      replay_time_frame(&pool, &app_state.amqp_config, timeframe).await?
  }
  ReplayMode::HeaderReplay(header) => {
      replay_header(&pool, &app_state.amqp_config, header).await?
  }
};
```],
caption: [match replay_mode]
)

The `replay_time_frame` function shown in @replay_time_frame or the `replay_header`
function shown in @replay_header returns the messages that should be replayed.

#pagebreak()
The vector of messages is passed to the `publish_message` function shown in @publish_message,
and later the newly published messages are returned as JSON as well as a status code 200.

#figure(
  sourcecode()[```rs
    let replayed_messages = replay::publish_message(&pool, &message_options, messages).await?;
    Ok((StatusCode::OK, Json(replayed_messages)))
```],
caption: [publish and return messages]
)

== Replay component

The replay component has four key functions.

#figure(tablex(
  columns: (auto, 1fr,auto),
  rows: (auto),
  align: (center + horizon, left,center + horizon),
  [*Name*],
  [*Description*],
  [*Link*],
  [fetch_messages],
  [returns a list of all messages in the queue based on the given filter],
  [@heading_fetch_messages],
  [replay_header],
  [returns a list of messages that contain the given header],
  [@heading_replay_header],
  [replay_time_frame],
  [returns a list of messages that are between the given timestamps],
  [@heading_replay_time_frame],
  [publish_message],
  [publishes a list of messages to the queue],
  [@heading_publish_message],
  [get_queue_message_count],
  [returns the number of messages in the queue],
  [@heading_get_queue_message_count],
), kind: table, caption: [replay key functions])


=== fetch_messages<heading_fetch_messages>

The `fetch_messages` function gets called when the `get_messages` handler is invoked.

#figure(
  sourcecode()[```rs
pub async fn fetch_messages(
  pool: &deadpool_lapin::Pool,
  rabbitmq_api_config: &RabbitmqApiConfig,
  message_options: &MessageOptions,
  message_query: MessageQuery,
) -> Result<Vec<Message>> {
let message_count =
    match get_queue_message_count(&rabbitmq_api_config, message_query.queue.as_str()).await? {
        Some(message_count) => message_count,
        None => {
            return Err(anyhow!("Queue not found or empty"));
        }
    };

let connection = pool.get().await?;
let channel = connection.create_channel().await?;

channel
    .basic_qos(1000u16, BasicQosOptions { global: false })
    .await?;

let mut consumer = channel
    .basic_consume(
        &message_query.queue,
        "fetch_messages",
        BasicConsumeOptions::default(),
        stream_consume_args(AMQPValue::LongString("first".into())),
    )
    .await?;

let mut messages = Vec::new();

while let Some(Ok(delivery)) = consumer.next().await {
    delivery.ack(BasicAckOptions::default()).await?;

    let headers = match delivery.properties.headers().as_ref() {
        Some(headers) => headers,
        None => return Err(anyhow!("No headers found")),
    };

    let transaction = match message_options.transaction_header.clone() {
        Some(transaction_header) => match headers.inner().get(transaction_header.as_str()) {
            Some(AMQPValue::LongString(transaction_id)) => Some(TransactionHeader {
                name: transaction_header,
                value: transaction_id.to_string(),
            }),
            _ => None,
        },
        None => None,
    };

    let offset = match headers.inner().get("x-stream-offset") {
        Some(AMQPValue::LongLongInt(offset)) => offset,
        _ => return Err(anyhow!("x-stream-offset not found")),
    };

    let timestamp = *delivery.properties.timestamp();

    match is_within_timeframe(timestamp, message_query.from, message_query.to) {
        Some(true) => {
            if *offset >= i64::try_from(message_count - 1)? {
                messages.push(Message {
                    offset: Some(*offset as u64),
                    transaction,
                    timestamp: Some(
                        chrono::Utc
                            .timestamp_millis_opt(timestamp.unwrap() as i64)
                            .unwrap(),
                    ),
                    data: String::from_utf8(delivery.data)?,
                });
                break;
            }
            messages.push(Message {
                offset: Some(*offset as u64),
                transaction,
                timestamp: Some(
                    chrono::Utc
                        .timestamp_millis_opt(timestamp.unwrap() as i64)
                        .unwrap(),
                ),
                data: String::from_utf8(delivery.data)?,
            });
        }
        Some(false) => {
            if *offset >= i64::try_from(message_count - 1)? {
                break;
            }
            continue;
        }
        None => {
            if *offset >= i64::try_from(message_count - 1)? {
                messages.push(Message {
                    offset: Some(*offset as u64),
                    transaction,
                    timestamp: None,
                    data: String::from_utf8(delivery.data)?,
                });
                break;
            }
            messages.push(Message {
                offset: Some(*offset as u64),
                transaction,
                timestamp: None,
                data: String::from_utf8(delivery.data)?,
            });
        }
    }
}
  Ok(messages)
}
```],
caption: [fetch_messages]
)<fetch_messages>

The function takes four arguments. The first argument is a reference to the 
connection pool. The second argument is a reference to the `RabbitmqApiConfig`
struct. The third argument is a reference to the `MessageOptions` struct. The 
fourth argument is a `MessageQuery` struct.

#figure(
  sourcecode()[```rs
pub async fn fetch_messages(
    pool: &deadpool_lapin::Pool,
    rabbitmq_api_config: &RabbitmqApiConfig,
    message_options: &MessageOptions,
    message_query: MessageQuery,
) -> Result<Vec<Message>> {
```],
caption: [fetch_messages function signature]
)

The function returns a `Result<Vec<Message>>`. 
#linebreak()

The `Message` holds the data that will be returned to the client.

#figure(
  sourcecode()[```rs
#[derive(Serialize, Debug)]
pub struct Message {
    #[serde(skip_serializing_if = "Option::is_none")]
    offset: Option<u64>,
    transaction: Option<TransactionHeader>,
    timestamp: Option<chrono::DateTime<chrono::Utc>>,
    data: String,
}
```],
caption: [Message]
)<Message_struct>

Each message in a stream has an offset. The offset is used to identify the
`x-stream-offset` header. The offset is optional on the `Message` struct because
the offset is only available when the message gets read from the stream. If the
message is being published, the publisher does not know the offset of the
message. Consumers could keep track of the last acknowledged offset and use this 
to identify the next message to consume from the stream.

#linebreak()
The `#[serde(skip_serializing_if = "Option::is_none")]` attribute is used to
skip serializing the field if the field is `None`. This results in a cleaner
JSON response.
#linebreak()

As shown in the @MessageOptions, the microservice can be configured to add a
transaction ID to the message. The transaction ID is added to the message as a
custom header. If this option is enabled, the `TransactionHeader` struct holds the name of the header and the value of the header for the specific
message.

#figure(
  sourcecode()[```rs
#[derive(Serialize, Debug)]
pub struct TransactionHeader {
    name: String,
    value: String,
}
```],
caption: [TransactionHeader]
)
Just like the transaction header, the timestamp is optional.
#linebreak()
The `data` field holds the actual message data.

First, the number of messages in the queue is fetched with the `get_queue_message_count` 
function shown in @heading_get_queue_message_count.
#figure(
sourcecode()[```rs
let message_count =
  match get_queue_message_count(&rabbitmq_api_config, message_query.queue.as_str()).await? {
      Some(message_count) => message_count,
      None => {
          return Err(anyhow!("Queue not found or empty"));
      }
  };
```],
caption: [match message count]
)


After the number of messages in the queue is known, a connection to the AMQP
server is established. A channel is created and the `basic_qos` method is called
on the channel. The `basic_qos` method is used to limit the number of messages
that are being prefetched from the queue. The `basic_qos` method is called with
a prefetch count of 1000. This means that the channel will only prefetch 1000
messages from the queue. This is necessary because the queue could contain
millions of messages and the microservice should not consume all messages at
once. If the microservice consumes all messages at once, the microservice
could run out of memory if the queue contains millions of messages.

#figure(
  sourcecode()[```rs
let connection = pool.get().await?;
let channel = connection.create_channel().await?;

channel
    .basic_qos(1000u16, BasicQosOptions { global: false })
    .await?;
```],
caption: [create channel and set prefetch count]
)

The `basic_consume` method is called on the channel. The `basic_consume` method 
is used to consume messages from the queue. The `basic_consume` method is called 
with the name of the queue, a consumer tag, the `BasicConsumeOptions` and the 
`stream_consume_args` function.

#figure(
  sourcecode()[```rs
let mut consumer = channel
    .basic_consume(
        &message_query.queue,
        "fetch_messages",
        BasicConsumeOptions::default(),
        stream_consume_args(AMQPValue::LongString("first".into())),
    )
    .await?;
```],
caption: [consume messages from queue]
)

The `basic_consume` method returns a `Consumer`. The `Consumer` implements the 
`Stream` trait. The `Consumer` is used to iterate over the messages in the queue.
#linebreak()

The `stream_consume_args` function takes an `AMQPValue` as an argument and
returns a `FieldTable`. The `FieldTable` is used to pass additional AMQP
arguments to the `basic_consume` method. The `x-stream-offset` argument is used
to specify the start position of the stream. The `x-stream-offset` argument is
set to `first`. This means the consumer will start reading from the first
message in the queue.

#figure(
  sourcecode()[```rs
fn stream_consume_args(stream_offset: AMQPValue) -> FieldTable {
    let mut args = FieldTable::default();
    args.insert(ShortString::from("x-stream-offset"), stream_offset);
    args
}
```],
caption: [stream_consume_args]
)

The `Consumer` is used to iterate over the messages in the queue. The `Consumer`
is a stream and the `next` method is called on the `Consumer`. The `next` method 
returns an `Option<Result<Delivery>>`. The `Delivery` struct holds the message 
data and the message metadata.
An issue with the consumer is, the consumer does not know when to stop
consuming messages. The consumer is a subscription-based approach. The consumer 
will keep consuming messages until the connection is closed. Therefore the 
iterator would never stop. 
#linebreak()


The `while let` loop is used to iterate over the messages and lift the `Option`
and `Result` from the `Consumer`.
#figure(
  sourcecode()[```rs
while let Some(Ok(delivery)) = consumer.next().await {
```],
caption: [consume messages from queue]
)

The `ack` method is called on the `Delivery`. The `ack` method is used to
acknowledge the message. If the message is not acknowledged, the message will be
redelivered to the consumer. If no message is acknowledged, the queue 
will not send more messages than the prefetch count.

#figure(
  sourcecode()[```rs
delivery.ack(BasicAckOptions::default()).await?;
```],
caption: [acknowledge message]
)

The `headers` property is extracted from the `Delivery`. 

#figure(
  sourcecode()[```rs
let headers = match delivery.properties.headers().as_ref() {
    Some(headers) => headers,
    None => return Err(anyhow!("No headers found")),
};
```],
caption: [extract headers]
)

Next, depending on the configuration, the transaction header is extracted from 
the `message_options` struct. If the transaction header is present, the 
transaction header is extracted from the `headers` struct. If the transaction 
header is not present, the transaction header is set to `None`.

#figure(
  sourcecode()[```rs
let transaction = match message_options.transaction_header.clone() {
    Some(transaction_header) => match headers.inner().get(transaction_header.as_str()) {
        Some(AMQPValue::LongString(transaction_id)) => Some(TransactionHeader {
            name: transaction_header,
            value: transaction_id.to_string(),
        }),
        _ => None,
    },
    None => None,
};
```],
caption: [extract transaction header]
)

Since the consumer would never know when to stop consuming messages, the offset 
of the message is extracted. The offset together with the number of messages in 
the queue is used to determine if the message is the last in the queue.

#figure(
  sourcecode()[```rs
let offset = match headers.inner().get("x-stream-offset") {
    Some(AMQPValue::LongLongInt(offset)) => offset,
    _ => return Err(anyhow!("x-stream-offset not found")),
};
```],
caption: [extract offset]
)

If for some unknown reason, the `x-stream-offset` header is not present, an error 
is returned.

After the offset is extracted, the timestamp is extracted from the `Delivery`
and the function `is_within_timeframe` is called. The `is_within_timeframe`
function shown in @heading_is_within_timeframe is used to determine if the
message is within the timeframe specified by the request.

#figure(
  sourcecode()[```rs
let timestamp = *delivery.properties.timestamp();
match is_within_timeframe(timestamp, message_query.from, message_query.to) {
```],
caption: [extract timestamp and call is_within_timeframe]
)



If the message is within the timeframe, the timestamp of the message is converted from a `u64` to a
`chrono::DateTime<chrono::Utc>` and the message is pushed to the `messages`
vector. 
#linebreak()
If the message has a timestamp and a time range is specified that does not 
contain the message, the message is skipped.
#linebreak()
If the message does not have a timestamp and no time range is specified, the message is pushed to the `messages` vector. 


#figure(
sourcecode(
  highlighted: (35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46,47,48,49,50,51),
  )[```rs
match is_within_timeframe(timestamp, message_query.from, message_query.to) {
  Some(true) => {
      if *offset >= i64::try_from(message_count - 1)? {
          messages.push(Message {
              offset: Some(*offset as u64),
              transaction,
              timestamp: Some(
                  //unwrap is save here, because we checked if timestamp is set
                  chrono::Utc
                      .timestamp_millis_opt(timestamp.unwrap() as i64)
                      .unwrap(),
              ),
              data: String::from_utf8(delivery.data)?,
          });
          break;
      }
      messages.push(Message {
          offset: Some(*offset as u64),
          transaction,
          timestamp: Some(
              //unwrap is save here, because we checked if timestamp is set
              chrono::Utc
                  .timestamp_millis_opt(timestamp.unwrap() as i64)
                  .unwrap(),
          ),
          data: String::from_utf8(delivery.data)?,
      });
  }
  Some(false) => {
      if *offset >= i64::try_from(message_count - 1)? {
          break;
      }
      continue;
  }
  None => {
      if *offset >= i64::try_from(message_count - 1)? {
          messages.push(Message {
              offset: Some(*offset as u64),
              transaction,
              timestamp: None,
              data: String::from_utf8(delivery.data)?,
          });
          break;
      }
      messages.push(Message {
          offset: Some(*offset as u64),
          transaction,
          timestamp: None,
          data: String::from_utf8(delivery.data)?,
      });
    }
}
```],
caption: [fetch_messages match is_within_timeframe]
)

By returning `None` from `is_within_timeframe` no additional check on the
timestamp is necessary because the difference between *not being in the timeframe*
and *not having a timestamp* is already handled by the `is_within_timeframe`
function shown in @heading_is_within_timeframe.
#linebreak()

Additionally, in each iteration the offset is checked if it is the last message,
to determine if the loop should be exited.
#sourcecode(numbering: none)[```rs
if *offset >= i64::try_from(message_count - 1)?{
 ```]
If the offset is the last message, the message is pushed to the `messages`
vector and the loop is exited.
#linebreak()
The pushed messages are returned from the `fetch_messages` function.

#sourcecode(numbering: none)[```rs
Ok(messages)
```]




=== replay_header<heading_replay_header>

The `replay_header` function gets called when messages should be replayed based
on a message header. The function returns zero or more messages *iff* the
message header value and the message header name match the given header value
and header name.

#figure(
  sourcecode()[```rs
pub async fn replay_header(
  pool: &deadpool_lapin::Pool,
  rabbitmq_api_config: &RabbitmqApiConfig,
  header_replay: HeaderReplay,
) -> Result<Vec<Delivery>> {

let message_count =
    match get_queue_message_count(&rabbitmq_api_config, &header_replay.queue).await? {
        Some(message_count) => message_count,
        None => return Err(anyhow!("Queue not found or empty")),
    };

let connection = pool.get().await?;

let channel = connection.create_channel().await?;

channel
    .basic_qos(1000u16, BasicQosOptions { global: false })
    .await?;

let mut consumer = channel
    .basic_consume(
        &header_replay.queue,
        "replay",
        BasicConsumeOptions::default(),
        stream_consume_args(AMQPValue::LongString("first".into())),
    )
    .await?;

let mut messages = Vec::new();

while let Some(Ok(delivery)) = consumer.next().await {
    delivery.ack(BasicAckOptions::default()).await?;
    let headers = match delivery.properties.headers().as_ref() {
        Some(headers) => headers,
        None => return Err(anyhow!("No headers found")),
    };

    let target_header = headers.inner().get(header_replay.header.name.as_str());
    let offset = match headers.inner().get("x-stream-offset") {
        Some(AMQPValue::LongLongInt(offset)) => offset,
        _ => return Err(anyhow!("Queue is not a stream")),
    };

    if *offset >= i64::try_from(message_count - 1)? {
        if let Some(AMQPValue::LongString(header)) = target_header {
            if *header.to_string() == header_replay.header.value {
                messages.push(delivery);
            }
        }
        break;
    }

    if let Some(AMQPValue::LongString(header)) = target_header {
        if *header.to_string() == header_replay.header.value {
            messages.push(delivery);
        }
    }
}
Ok(messages)
}
```],
caption: [replay_header]
)<replay_header>

The function takes three arguments. The first argument is a reference to the 
connection pool. The second argument is a reference to the `RabbitmqApiConfig`
struct. The third argument is a `HeaderReplay` struct.
  
#figure(
  sourcecode()[```rs
pub async fn replay_header(
    pool: &deadpool_lapin::Pool,
    rabbitmq_api_config: &RabbitmqApiConfig,
    header_replay: HeaderReplay,
) -> Result<Vec<Delivery>> {
```],
caption: [replay_header function signature]
)

The function returns a `Result<Vec<Delivery>>`. The `Delivery`#footnote("https://docs.rs/lapin/latest/lapin/message/struct.Delivery.html") struct
represents a received AMQP message and is defined in the `lapin` crate.
#linebreak()

The function starts by fetching the number of messages in the queue. The number of 
messages in the queue is used to determine if the message is the last message in the queue in the 
same way as shown in @heading_fetch_messages.

#figure(
  sourcecode()[```rs
let message_count =
    match get_queue_message_count(&rabbitmq_api_config, &header_replay.queue).await? {
        Some(message_count) => message_count,
        None => return Err(anyhow!("Queue not found or empty")),
    };
```],
caption: [match message count]
)

After the number of messages in the queue is known, a connection to the AMQP 
server is established. A channel is created and the `basic_qos` method is called
on the channel. 
#linebreak()
A new vector called `messages` is created. The `messages` vector is used to
store the messages that should be replayed.

#figure(
  sourcecode()[```rs
let connection = pool.get().await?;

let channel = connection.create_channel().await?;

channel
    .basic_qos(1000u16, BasicQosOptions { global: false })
    .await?;

let mut consumer = channel
    .basic_consume(
        &header_replay.queue,
        "replay",
        BasicConsumeOptions::default(),
        stream_consume_args(AMQPValue::LongString("first".into())),
    )
    .await?;
let mut messages = Vec::new();
```],
caption: [create channel and set prefetch count]
)

The `next` method is called on the `Consumer` to iterate over the messages in the queue.

#figure(
  sourcecode()[```rs
while let Some(Ok(delivery)) = consumer.next().await {
```],
caption: [consume messages from queue]
)

#pagebreak()
In the `while let` loop the `ack` method is called on the `Delivery`. After acknowledging the message,
the `headers` property is extracted from the `Delivery`.

#figure(
  sourcecode()[```rs
delivery.ack(BasicAckOptions::default()).await?;
let headers = match delivery.properties.headers().as_ref() {
    Some(headers) => headers,
    None => return Err(anyhow!("No headers found")),
};
```],
caption: [extract headers]
)

The `target_header` is extracted from the `headers` struct. The `target_header` is the header that 
should be matched against the `header_replay.header` field.

#figure(
  sourcecode()[```rs
let target_header = headers.inner().get(header_replay.header.name.as_str());
```],
caption: [extract target header]
)

The `offset` is extracted from the `headers` struct. The `offset` is used to determine if the message 
is the last message in the queue.

#figure(
  sourcecode()[```rs
let offset = match headers.inner().get("x-stream-offset") {
    Some(AMQPValue::LongLongInt(offset)) => offset,
    _ => return Err(anyhow!("Queue is not a stream")),
};
```],
caption: [extract offset]
)

If the offset is the last message, the `target_header` is matched against the 
`header_replay.header` field. If the `target_header` matches the 
`header_replay.header` field, the `delivery` is pushed to the `messages` vector
and the loop is exited.

#figure(
  sourcecode()[```rs
if *offset >= i64::try_from(message_count - 1)? {
  if let Some(AMQPValue::LongString(header)) = target_header {
      if *header.to_string() == header_replay.header.value {
          messages.push(delivery);
      }
  }
  break;
}
```],
caption: [match target header and break loop]
)

If the offset is not the last message, the `target_header` is matched against
the `header_replay.header` field. If the `target_header` matches the 
`header_replay.header` field, the `delivery` is pushed to the `messages` vector. If
the `target_header` does not match the `header_replay.header` field, the message 
is skipped.

#figure(
  sourcecode()[```rs
if let Some(AMQPValue::LongString(header)) = target_header {
  if *header.to_string() == header_replay.header.value {
      messages.push(delivery);
  }
}
```],
caption: [match target header]
)

The `messages` vector is returned from the `replay_header` function.

#figure(
  sourcecode()[```rs
Ok(messages)
```],
caption: [return messages]
)

=== replay_time_frame<heading_replay_time_frame>

The `replay_time_frame` function gets called when messages should be replayed 
based on a time frame. The function returns zero or more messages *iff* the 
message timestamp is within the given time frame.

#figure(
  sourcecode()[```rs
pub async fn replay_time_frame(
  pool: &deadpool_lapin::Pool,
  rabbitmq_api_config: &RabbitmqApiConfig,
  time_frame: TimeFrameReplay,
) -> Result<Vec<Delivery>> {
  let message_count =
      match get_queue_message_count(&rabbitmq_api_config, &time_frame.queue).await? {
          Some(message_count) => message_count,
          None => return Err(anyhow!("Queue not found or empty")),
      };

  let connection = pool.get().await?;
  let channel = connection.create_channel().await?;

  channel
      .basic_qos(1000u16, BasicQosOptions { global: false })
      .await?;

  let mut consumer = channel
      .basic_consume(
          &time_frame.queue,
          "replay",
          BasicConsumeOptions::default(),
          stream_consume_args(AMQPValue::LongString("first".into())),
      )
      .await?;

  let mut messages = Vec::new();
  while let Some(Ok(delivery)) = consumer.next().await {
      delivery.ack(BasicAckOptions::default()).await?;
      let headers = match delivery.properties.headers().as_ref() {
          Some(headers) => headers,
          None => return Err(anyhow!("No headers found")),
      };
      let offset = match headers.inner().get("x-stream-offset") {
          Some(AMQPValue::LongLongInt(offset)) => offset,
          _ => return Err(anyhow!("x-stream-offset not found")),
      };
      let timestamp = *delivery.properties.timestamp();

      match is_within_timeframe(timestamp, Some(time_frame.from), Some(time_frame.to)) {
          Some(true) => {
              if *offset >= i64::try_from(message_count - 1)? {
                  messages.push(delivery);
                  break;
              }
              messages.push(delivery);
          }
          _ => {
              if *offset >= i64::try_from(message_count - 1)? {
                  break;
              }
              continue;
          }
      }
  }
  Ok(messages)
}
```],
caption: [replay_time_frame]
)<replay_time_frame>

The function takes three arguments. The first argument is a reference to the 
connection pool. The second argument is a reference to the `RabbitmqApiConfig`
struct. The third argument is a `TimeFrameReplay` struct.

#figure(
  sourcecode()[```rs
pub async fn replay_time_frame(
    pool: &deadpool_lapin::Pool,
    rabbitmq_api_config: &RabbitmqApiConfig,
    time_frame: TimeFrameReplay,
) -> Result<Vec<Delivery>> {
```],
caption: [replay_time_frame function signature]
)

The function returns a `Result<Vec<Delivery>>`. The `Delivery`#footnote("https://docs.rs/lapin/latest/lapin/message/struct.Delivery.html") struct
represents a received AMQP message and is defined in the `lapin` crate.
#linebreak()
The function starts by fetching the number of messages in the queue. The number of
messages in the queue is used to determine if the message is the last message in the queue in the 
same way as shown in @heading_fetch_messages or @heading_replay_header.

#figure(
  sourcecode()[```rs
let message_count =
    match get_queue_message_count(&rabbitmq_api_config, &time_frame.queue).await? {
        Some(message_count) => message_count,
        None => return Err(anyhow!("Queue not found or empty")),
    };
```],
caption: [match message count]
)

After the number of messages in the queue is known, a connection to the AMQP 
server is established. A channel is created and the `basic_qos` method is called
on the channel.
#linebreak()
A new vector called `messages` is created. The `messages` vector is used to
store the messages that should be replayed.

#figure(
  sourcecode()[```rs
let connection = pool.get().await?;
let channel = connection.create_channel().await?;

channel
    .basic_qos(1000u16, BasicQosOptions { global: false })
    .await?;

let mut consumer = channel
    .basic_consume(
        &time_frame.queue,
        "replay",
        BasicConsumeOptions::default(),
        stream_consume_args(AMQPValue::LongString("first".into())),
    )
    .await?;

let mut messages = Vec::new();
```],
caption: [create channel and set prefetch count]
)

The `next` method is called on the `Consumer` to iterate over the messages in the queue.

#figure(
  sourcecode()[```rs
while let Some(Ok(delivery)) = consumer.next().await {
```],
caption: [consume messages from queue]
)

In the `while let` loop the `ack` method is called on the `Delivery`. After acknowledging the message,
the `headers` property is extracted from the `Delivery`.

#figure(
  sourcecode()[```rs
delivery.ack(BasicAckOptions::default()).await?;
let headers = match delivery.properties.headers().as_ref() {
    Some(headers) => headers,
    None => return Err(anyhow!("No headers found")),
};
```],
caption: [extract headers]
)

The `offset` is extracted from the `headers` struct. The `offset` is used to determine if the message 
is the last message in the queue.

#figure(
  sourcecode()[```rs
let offset = match headers.inner().get("x-stream-offset") {
    Some(AMQPValue::LongLongInt(offset)) => offset,
    _ => return Err(anyhow!("x-stream-offset not found")),
};
```],
caption: [extract offset]
)

#pagebreak()
The `timestamp` is extracted from the `Delivery`. The `timestamp` is used as argument for the 
`is_within_timeframe` function shown in @heading_is_within_timeframe. The `is_within_timeframe`
takes the `Delivery` timestamp, the `from` and the `to` fields of the `TimeFrameReplay` struct as
arguments. The `is_within_timeframe`.

#figure(
  sourcecode()[```rs
let timestamp = *delivery.properties.timestamp();
match is_within_timeframe(timestamp, Some(time_frame.from), Some(time_frame.to)) {
    Some(true) => {
        if *offset >= i64::try_from(message_count - 1)? {
            messages.push(delivery);
            break;
        }
        messages.push(delivery);
    }
    _ => {
        if *offset >= i64::try_from(message_count - 1)? {
            break;
        }
        continue;
    }
}
```],
caption: [match timeframe]
)

If the message is within the timeframe, the message is pushed to the `messages`
vector, additionally if the message is the last message in the queue, the loop
is exited.
#linebreak()
If the message is not within the timeframe, the message is skipped. If the
message is the last message in the queue, the loop is exited.
#linebreak()

Lastly the `messages` vector is returned from the `replay_time_frame` function.

#figure(
  sourcecode()[```rs
Ok(messages)
```],
caption: [return messages]
)

#pagebreak()

=== is_within_timeframe<heading_is_within_timeframe>

The `is_within_timeframe` function takes three arguments. The first argument is
the timestamp of the message. The second argument is the `from` parameter of the 
request. The third argument is the `to` parameter of the request. The function 
returns an `Option<bool>`.

#figure(
  sourcecode()[```rs 
  fn is_within_timeframe(
    date: Option<u64>,
    from: Option<chrono::DateTime<chrono::Utc>>,
    to: Option<chrono::DateTime<chrono::Utc>>,
) -> Option<bool> {
  match date {
      Some(date) => {
          let date = Utc.timestamp_millis_opt(date as i64).unwrap();
          match (from, to) {
              (Some(from), Some(to)) => Some(date >= from && date <= to),
              (Some(from), None) => Some(date >= from),
              (None, Some(to)) => Some(date <= to),
              (None, None) => Some(true),
          }
      }
      None => match (from, to) {
          (None, None) => None,
          _ => Some(false),
      },
  }
}
```],
caption: [is_within_timeframe]
)

The function checks if the message has a timestamp. If the message has a
timestamp, the function checks if the timestamp is within the given from and to
parameters. If the message does not have a timestamp, the function checks if the 
from and to parameters are `None`. If the from and to parameters are `None`, the 
function returns `None` otherwise the function returns `Some(false)`.
#linebreak()
The function needs to return an `Option<bool>` because the message does not 
necessarily have a timestamp. If the message does not have a timestamp, the 
function returns `None`. If the message has a timestamp, the function returns 
`Some(true)` or `Some(false)` depending on the from and to parameters.
This results in the following matrix.

#figure(
  tablex(
    columns: (auto, auto, auto, 1fr),
    rows: (auto),
    align: (center + horizon, center + horizon, center + horizon, left),
    [*message timestamp*],
    [*from*],
    [*to*],
    [*result*],
    [Some],
    [Some],
    [Some],
    [Some(message timestamp >= from && message timestamp <= to)],
    [Some],
    [Some],
    [None],
    [Some(message timestamp >= from)],
    [Some],
    [None],
    [Some],
    [Some(message timestamp <= to)],
    [Some],
    [None],
    [None],
    [Some(true)],
    [None],
    [Some],
    [Some],
    [Some(false)],
    [None],
    [None],
    [Some],
    [Some(false)],
    [None],
    [Some],
    [None],
    [Some(false)],
    cellx(fill: rgb(234, 234,189))[None],
    cellx(fill: rgb(234, 234,189))[None],
    cellx(fill: rgb(234, 234,189))[None],
    cellx(fill: rgb(234, 234,189))[None],
    ),
  kind: table,
  caption: [is_within_timeframe matrix]
  )<is_within_timeframe_matrix>

=== publish_message<heading_publish_message>

The `publish_message` function is used to publish messages that should be
replayed to the queue again. 

#figure(
  sourcecode()[```rs
pub async fn publish_message(
  pool: &deadpool_lapin::Pool,
  message_options: &MessageOptions,
  messages: Vec<Delivery>,
) -> Result<Vec<Message>> {
  let connection = pool.get().await?;
  let channel = connection.create_channel().await?;
  let mut s = stream::iter(messages);
  let mut replayed_messages = Vec::new();

  while let Some(message) = s.next().await {
      let mut transaction: Option<TransactionHeader> = None;
      let mut timestamp: Option<chrono::DateTime<chrono::Utc>> = None;
      let basic_props = match (
          message_options.enable_timestamp,
          message_options.transaction_header.clone(),
      ) {
          (true, None) => {
              timestamp = Some(chrono::Utc::now());
              let timestamp_u64 = timestamp.unwrap().timestamp_millis() as u64;
              lapin::BasicProperties::default().with_timestamp(timestamp_u64)
          }
          (true, Some(transaction_header)) => {
              timestamp = Some(chrono::Utc::now());
              let timestamp_u64 = timestamp.unwrap().timestamp_millis() as u64;
              let uuid = uuid::Uuid::new_v4().to_string();
              let mut headers = FieldTable::default();
              headers.insert(
                  ShortString::from(transaction_header.as_str()),
                  AMQPValue::LongString(uuid.as_str().into()),
              );
              transaction = TransactionHeader::from_fieldtable(
                  headers.clone(),
                  transaction_header.as_str(),
              )
              .ok();
              lapin::BasicProperties::default()
                  .with_headers(headers)
                  .with_timestamp(timestamp_u64)
          }
          (false, None) => lapin::BasicProperties::default(),
          (false, Some(transaction_header)) => {
              let uuid = uuid::Uuid::new_v4().to_string();
              let mut headers = FieldTable::default();
              headers.insert(
                  ShortString::from(transaction_header.as_str()),
                  AMQPValue::LongString(uuid.as_str().into()),
              );
              transaction = TransactionHeader::from_fieldtable(
                  headers.clone(),
                  transaction_header.as_str(),
              )
              .ok();
              lapin::BasicProperties::default().with_headers(headers)
          }
      };

      channel
          .basic_publish(
              message.exchange.as_str(),
              message.routing_key.as_str(),
              lapin::options::BasicPublishOptions::default(),
              message.data.as_slice(),
              basic_props,
          )
          .await?;

      replayed_messages.push(Message {
          offset: None,
          transaction,
          timestamp,
          data: String::from_utf8(message.data)?,
      });
  }
  Ok(replayed_messages)
}
```],
caption: [publish_message]
)<publish_message>

The function takes three arguments. The first argument is a reference to the 
connection pool. The second argument is a reference to the `MessageOptions`
struct. The third argument is a vector of `Delivery` structs.

#figure(
  sourcecode()[```rs
pub async fn publish_message(
    pool: &deadpool_lapin::Pool,
    message_options: &MessageOptions,
    messages: Vec<Delivery>,
) -> Result<Vec<Message>> {
```],
caption: [publish_message function signature]
)

The function returns a `Result<Vec<Message>>`. The `Message` struct is defined
in @Message_struct.
#linebreak()

The function starts by establishing a connection to the AMQP server. A channel
is created and a stream#footnote("https://rust-lang.github.io/async-book/05_streams/01_chapter.html")
is created from the `messages` vector. A stream in Rust is an asynchronous
iterator. The `next` method is called on the stream to iterate over the messages
in the `messages` vector. A new vector called `replayed_messages` is created.
The `replayed_messages` vector is used to store the messages that should be
returned from the function to the client.

#figure(
  sourcecode()[```rs
let connection = pool.get().await?;
let channel = connection.create_channel().await?;
let mut s = stream::iter(messages);
let mut replayed_messages = Vec::new();
while let Some(message) = s.next().await {
```],
caption: [create channel and stream]
)

As shown in @MessageOptions, the microservice supports 
adding a custom transaction header or a timestamp to a message.
Both of these features are optional thus resulting in the following matrix.


#figure(
  tablex(
    columns: (auto, auto, 1fr),
    rows: (auto),
    align: (center + horizon, center + horizon, left),
    [*enable_timestamp*],
    [*transaction_header*],
    [*result*],
    [true],
    [None],
    [timestamp is added to message],
    [true],
    [Some],
    [timestamp and transaction header are added to message],
    [false],
    [Some],
    [transaction header is added to message],
    [false],
    [None],
    [no timestamp or transaction header are added to message],
    ),
    kind: table,
    caption: [publish options matrix]
  )<publish_options_matrix>

To represent the matrix in code, the `enable_timestamp` and `transaction_header`
field are matched as tuples.

#figure(
  sourcecode()[```rs
        let basic_props = match (
            message_options.enable_timestamp,
            message_options.transaction_header.clone(),
        ) {
            (true, None) => {
                timestamp = Some(chrono::Utc::now());
                let timestamp_u64 = timestamp.unwrap().timestamp_millis() as u64;
                lapin::BasicProperties::default().with_timestamp(timestamp_u64)
            }
            (true, Some(transaction_header)) => {
                timestamp = Some(chrono::Utc::now());
                let timestamp_u64 = timestamp.unwrap().timestamp_millis() as u64;
                let uuid = uuid::Uuid::new_v4().to_string();
                let mut headers = FieldTable::default();
                headers.insert(
                    ShortString::from(transaction_header.as_str()),
                    AMQPValue::LongString(uuid.as_str().into()),
                );
                transaction = TransactionHeader::from_fieldtable(
                    headers.clone(),
                    transaction_header.as_str(),
                )
                .ok();
                lapin::BasicProperties::default()
                    .with_headers(headers)
                    .with_timestamp(timestamp_u64)
            }
            (false, None) => lapin::BasicProperties::default(),
            (false, Some(transaction_header)) => {
                let uuid = uuid::Uuid::new_v4().to_string();
                let mut headers = FieldTable::default();
                headers.insert(
                    ShortString::from(transaction_header.as_str()),
                    AMQPValue::LongString(uuid.as_str().into()),
                );
                transaction = TransactionHeader::from_fieldtable(
                    headers.clone(),
                    transaction_header.as_str(),
                )
                .ok();
                lapin::BasicProperties::default().with_headers(headers)
            }
        };
```],
caption: [match publish options]
)

Each match arm sets the needed amqp properties and headers according to the 
matrix shown in @publish_options_matrix.
#linebreak()
  
After the needed properties are set, the `basic_publish` method is called on the 
channel. The routing key, exchange and data are taken from message.
The same message is pushed to the `replayed_messages` vector.

#figure(
  sourcecode()[```rs
channel
    .basic_publish(
        message.exchange.as_str(),
        message.routing_key.as_str(),
        lapin::options::BasicPublishOptions::default(),
        message.data.as_slice(),
        basic_props,
    )
    .await?;

replayed_messages.push(Message {
    offset: None,
    transaction,
    timestamp,
    data: String::from_utf8(message.data)?,
});
    ```],
caption: [publish  messages again]
)

The `replayed_messages` vector is returned from the `publish_message` function.

#figure(
  sourcecode()[```rs
Ok(replayed_messages)
```],
caption: [return replayed messages]
)

=== get_queue_message_count<heading_get_queue_message_count>

The `get_queue_message_count` function is used to retrieve metadata about the
queue using the RabbitMQ management API. This is necessary because the AMQP
protocol does not provide a way to check if a queue does actually exist or how many  messages are in the queue. The only way to get the
number of messages in a queue using the AMQP protocol is to declare the queue
again.  If the queue already exists, the number of messages in
the queue is returned as wanted but if the queue does not exist, the queue gets
created. This is not the desired behaviour. Therefore the RabbitMQ management
API is used.

#figure(
  sourcecode()[```rs
  async fn get_queue_message_count(
    rabitmq_api_config: &RabbitmqApiConfig,
    name: &str,
) -> Result<Option<u64>> {
    let client = reqwest::Client::new();

    let url = format!(
        "http://{}:{}/api/queues/%2f/{}",
        rabitmq_api_config.host, rabitmq_api_config.port, name
    );

    let res = client
        .get(url)
        .basic_auth(
            rabitmq_api_config.username.clone(),
            Some(rabitmq_api_config.password.clone()),
        )
        .send()
        .await?
        .json::<serde_json::Value>()
        .await?;

    if let Some(res) = res.get("type") {
        if res != "stream" {
            return Err(anyhow!("Queue is not a stream"));
        }
    }

    let message_count = res.get("messages");

    match message_count {
        Some(message_count) => Ok(Some(message_count.as_u64().unwrap())),
        None => Ok(None),
    }
}
```],
caption: [get_queue_message_count]
)

The function takes two arguments. The first argument is a reference to the 
`RabbitmqApiConfig` struct. The second argument is a reference to the name of
the queue that should be queried.

#figure(
sourcecode()[```rs 
async fn get_queue_message_count(
    rabitmq_api_config: &RabbitmqApiConfig,
    name: &str,
) -> Result<Option<u64>> {
```],
caption: [get_queue_message_count function signature]
)

The function returns a `Result<Option<u64>>`. 
If the queue is not of type `stream` an error is returned otherwise the number 
of messages in the queue is returned.
#pagebreak()
First, a new HTTP client is created. The URL to the RabbitMQ management API is 
constructed using the `RabbitmqApiConfig` struct.

#figure(
  sourcecode()[```rs
let client = reqwest::Client::new();

let url = format!(
    "http://{}:{}/api/queues/%2f/{}",
    rabitmq_api_config.host, rabitmq_api_config.port, name
);
```],
caption: [create HTTP client]
)

The client is used to send a `GET` request to the RabbitMQ management API.
The management API is protected by basic authentication. Therefore the username 
and password are added to the request.
The response is deserialized into a `serde_json::Value` struct.

#figure(
  sourcecode()[```rs
let res = client
    .get(url)
    .basic_auth(
        rabitmq_api_config.username.clone(),
        Some(rabitmq_api_config.password.clone()),
    )
    .send()
    .await?
    .json::<serde_json::Value>()
    .await?;
```],
caption: [send a GET request to RabbitMQ management API]
)

The response is checked if the queue is of type `stream`. If the queue is not of
type `stream` an error is returned.

#figure(
  sourcecode()[```rs
if let Some(res) = res.get("type") {
    if res != "stream" {
        return Err(anyhow!("Queue is not a stream"));
    }
}
```],
caption: [check if queue is of type stream]
)

The `messages` field is read from the response. If the field is present, the 
number of messages in the queue is returned otherwise `None` is returned.

#figure(
  sourcecode()[```rs
let message_count = res.get("messages");

match message_count {
    Some(message_count) => Ok(Some(message_count.as_u64().unwrap())),
    None => Ok(None),
}
```],
caption: [return number of messages in queue]
)
#pagebreak()

== Testing

The project contains two types of tests. The first type of tests are unit tests
and the second type of tests are integration tests. Most functionalities of the
replay microservice require a connection to a RabbitMQ server therefore more
integration tests than unit tests are present. The integration tests use the
library testcontainers#footnote("https://testcontainers.com/") to spin up a
RabbitMQ server in a container for the tests. For each test, a new container is
created. The container is destroyed after the test is finished. The tests are
run in parallel to speed up the test execution.
#linebreak()
For all integration tests, some dummy data is needed in the queue. The dummy 
data is created using the `create_dummy_data` function.

#figure(
  sourcecode()[```rs
  async fn create_dummy_data(
    port: u16,
    message_count: i64,
    queue_name: &str,
) -> Result<Vec<Message>> {
    let connection_string = format!("amqp://guest:guest@127.0.0.1:{port}");
    let connection =
        Connection::connect(&connection_string, ConnectionProperties::default()).await?;

    let channel = connection.create_channel().await?;

    let _ = channel
        .queue_delete(queue_name, QueueDeleteOptions::default())
        .await;

    let mut queue_args = FieldTable::default();
    queue_args.insert(
        ShortString::from("x-queue-type"),
        AMQPValue::LongString("stream".into()),
    );

    channel
        .queue_declare(
            queue_name,
            QueueDeclareOptions {
                durable: true,
                auto_delete: false,
                ..Default::default()
            },
            queue_args,
        )
        .await?;
    let mut messages = Vec::new();
    for i in 0..message_count {
        let data = b"test";
        let timestamp = Utc::now().timestamp_millis() as u64;
        let transaction_id = format!("transaction_{}", i);
        let mut headers = FieldTable::default();
        headers.insert(
            ShortString::from("x-stream-transaction-id"),
            AMQPValue::LongString(transaction_id.clone().into()),
        );

        channel
            .basic_publish(
                "",
                queue_name,
                BasicPublishOptions::default(),
                data,
                AMQPProperties::default()
                    .with_headers(headers.clone())
                    .with_timestamp(timestamp),
            )
            .await?;
        messages.push(Message {
            offset: Some(i as u64),
            transaction: Some(TransactionHeader::from_fieldtable(
                headers,
                "x-stream-transaction-id",
            )?),
            data: String::from_utf8(data.to_vec())?,
            timestamp: Some(chrono::Utc.timestamp_millis_opt(timestamp as i64).unwrap()),
        });
        tokio::time::sleep(tokio::time::Duration::from_micros(1)).await;
    }
    Ok(messages)
}
```],
caption: [create_dummy_data]
)

The function takes three arguments. The first argument is the port of the 
RabbitMQ server. The second argument is the number of messages that should be
created. The third argument is the name of the queue that should be used.
The function returns a `Result<Vec<Message>>`. The `Message` struct is defined
in @Message_struct.
#linebreak()
The function starts by establishing a connection to the RabbitMQ server. A
channel is created and the queue is deleted if it already exists. The queue is
created with the type `stream`. Afterwards a unique transaction id and timestamp 
is generated for each message. The message is published to the queue. The 
function returns the published messages.
#linebreak()
In order to ensure that the messages are published correctly, the `i_test_setup`
test checks if the number of messages in the queue is equal to the number of
messages that were published.

#pagebreak()

#figure(
  sourcecode()[```rs
  #[tokio::test]
async fn i_test_setup() -> Result<()> {
    let docker = clients::Cli::default();
    let image = GenericImage::new("rabbitmq", "3.12-management").with_wait_for(
        testcontainers::core::WaitFor::message_on_stdout("started TCP listener on [::]:5672"),
    );
    let image = image.with_exposed_port(5672).with_exposed_port(15672);
    let node = docker.run(image);
    let amqp_port = node.get_host_port_ipv4(5672);
    let management_port = node.get_host_port_ipv4(15672);
    let message_count = 500;
    let queue_name = "replay";
    let messages = create_dummy_data(amqp_port, message_count, queue_name).await?;
    let client = reqwest::Client::new();

    loop {
        let res = client
            .get(format!(
                "http://localhost:{}/api/queues/%2f/{}",
                management_port, queue_name
            ))
            .basic_auth("guest", Some("guest"))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
        match res.get("messages") {
            Some(m) => {
                match res.get("type") {
                    Some(t) => assert_eq!(t.as_str().unwrap(), "stream"),
                    None => panic!("type not found"),
                }
                assert_eq!(m.as_i64().unwrap(), message_count);
                break;
            }
            None => continue,
        }
    }
    assert_eq!(messages.len(), message_count as usize);
    Ok(())
}
```],
caption: [integration test setup]
)

The test starts by pulling the `rabbitmq:3.12-management` image from Docker Hub.
The image is started and the ports `5672` and `15672` are exposed. The `5672` port 
is the port of the RabbitMQ server. The `15672` port is the port of the RabbitMQ 
management API. The `create_dummy_data` function is called to create the dummy 
data. The `reqwest` library is used to send a `GET` request to the RabbitMQ 
management API. The response is deserialized into a `serde_json::Value` struct.
The `messages` field is read from the response and checked if the `message_count`
is equal to the number of messages that were published. If the number of messages 
is equal, the test succeeds otherwise the test fails.
#pagebreak()
The `i_test_fetch_messages` test checks if the `fetch_messages` function returns
the correct messages.
#figure(
  sourcecode()[```rs
  #[tokio::test]
async fn i_test_fetch_messsages() -> Result<()> {
    let docker = clients::Cli::default();
    let image = GenericImage::new("rabbitmq", "3.12-management").with_wait_for(
        testcontainers::core::WaitFor::message_on_stdout("started TCP listener on [::]:5672"),
    );
    let image = image.with_exposed_port(5672).with_exposed_port(15672);
    let node = docker.run(image);
    let amqp_port = node.get_host_port_ipv4(5672);
    let management_port = node.get_host_port_ipv4(15672);

    let message_count = 500;
    let queue_name = "replay";
    let published_messages = create_dummy_data(amqp_port, message_count, queue_name).await?;
    let client = reqwest::Client::new();
    loop {
        let res = client
            .get(format!(
                "http://localhost:{}/api/queues/%2f/{}",
                management_port, queue_name
            ))
            .basic_auth("guest", Some("guest"))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
        match res.get("messages") {
            Some(m) => {
                match res.get("type") {
                    Some(t) => assert_eq!(t.as_str().unwrap(), "stream"),
                    None => panic!("type not found"),
                }
                assert_eq!(m.as_i64().unwrap(), message_count);
                break;
            }
            None => continue,
        }
    }

    let mut cfg = Config::default();
    cfg.url = Some(format!("amqp://guest:guest@127.0.0.1:{}/%2f", amqp_port));

    cfg.pool = Some(PoolConfig::new(1));

    let pool = cfg.create_pool(Some(Runtime::Tokio1)).unwrap();
    let rabbitmq_config = RabbitmqApiConfig {
        username: "guest".to_string(),
        password: "guest".to_string(),
        host: "localhost".to_string(),
        port: management_port.to_string(),
    };

    let message_options = rabbit_revival::MessageOptions {
        transaction_header: Some("x-stream-transaction-id".to_string()),
        enable_timestamp: true,
    };

    let message_query = MessageQuery {
        queue: queue_name.to_string(),
        from: None,
        to: None,
    };

    let messages = fetch_messages(&pool, &rabbitmq_config, &message_options, message_query).await?;

    assert_eq!(messages.len(), message_count as usize);

    messages.iter().enumerate().for_each(|(i, m)| {
        assert_eq!(m.data, published_messages[i].data);
        assert_eq!(m.offset, published_messages[i].offset);
        assert_eq!(m.timestamp, published_messages[i].timestamp);
        assert_eq!(
            m.transaction.as_ref().unwrap().name,
            published_messages[i].transaction.as_ref().unwrap().name
        );
        assert_eq!(
            m.transaction.as_ref().unwrap().value,
            published_messages[i].transaction.as_ref().unwrap().value
        );
    });

    Ok(())
}
```],
caption: [integration test fetch messages]
)

The test starts by starting the RabbitMQ server and creating the dummy data.
The `fetch_messages` function is called with the `from` and `to` parameters set 
to `None`. The `fetch_messages` function returns all messages in the queue.
The returned messages are compared to the published messages. If the messages are 
equal, the test succeeds otherwise the test fails.
#pagebreak()
The `i_test_replay_time_frame` test checks if the `replay_time_frame` function 
publishes the correct messages.
#figure(
  sourcecode()[```rs
  #[tokio::test]
async fn i_test_replay_time_frame() -> Result<()> {
    let docker = clients::Cli::default();
    let image = GenericImage::new("rabbitmq", "3.12-management").with_wait_for(
        testcontainers::core::WaitFor::message_on_stdout("started TCP listener on [::]:5672"),
    );
    let image = image.with_exposed_port(5672).with_exposed_port(15672);
    let node = docker.run(image);
    let amqp_port = node.get_host_port_ipv4(5672);
    let management_port = node.get_host_port_ipv4(15672);

    let message_count = 500;
    let queue_name = "replay";
    let published_messages = create_dummy_data(amqp_port, message_count, queue_name).await?;
    let client = reqwest::Client::new();
    loop {
        let res = client
            .get(format!(
                "http://localhost:{}/api/queues/%2f/{}",
                management_port, queue_name
            ))
            .basic_auth("guest", Some("guest"))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
        match res.get("messages") {
            Some(m) => {
                match res.get("type") {
                    Some(t) => assert_eq!(t.as_str().unwrap(), "stream"),
                    None => panic!("type not found"),
                }
                assert_eq!(m.as_i64().unwrap(), message_count);
                break;
            }
            None => continue,
        }
    }

    let mut cfg = Config::default();
    cfg.url = Some(format!("amqp://guest:guest@localhost:{}/%2f", amqp_port));

    cfg.pool = Some(PoolConfig::new(1));

    let pool = cfg.create_pool(Some(Runtime::Tokio1)).unwrap();
    let rabbitmq_config = RabbitmqApiConfig {
        username: "guest".to_string(),
        password: "guest".to_string(),
        host: "localhost".to_string(),
        port: management_port.to_string(),
    };

    let time_frame_replay = TimeFrameReplay {
        queue: queue_name.to_string(),
        from: published_messages.first().unwrap().timestamp.unwrap(),
        to: published_messages.last().unwrap().timestamp.unwrap(),
    };

    let replayed_messages = replay_time_frame(&pool, &rabbitmq_config, time_frame_replay).await?;

    assert_eq!(replayed_messages.len(), published_messages.len());

    replayed_messages.iter().enumerate().for_each(|(i, m)| {
        let m = m.clone();
        assert_eq!(
            String::from_utf8(m.data.clone()).unwrap(),
            published_messages[i].data
        );
        let headers = m.properties.headers().clone().unwrap();
        let offset = headers.inner().get("x-stream-offset").unwrap();
        let offset = match offset {
            AMQPValue::LongLongInt(i) => i,
            _ => panic!("offset not found"),
        };
        let timestamp = m.properties.timestamp().unwrap();
        let timestamp = Utc.timestamp_millis_opt(timestamp as i64).unwrap();
        assert_eq!(*offset as u64, published_messages[i].offset.unwrap());
        assert_eq!(timestamp, published_messages[i].timestamp.unwrap());
    });

    let time_frame_replay = TimeFrameReplay {
        queue: queue_name.to_string(),
        from: published_messages.last().unwrap().timestamp.unwrap(),
        to: published_messages.last().unwrap().timestamp.unwrap(),
    };
    let replayed_messages = replay_time_frame(&pool, &rabbitmq_config, time_frame_replay).await?;
    assert_eq!(replayed_messages.len(), 1);

    assert_eq!(
        String::from_utf8(replayed_messages[0].data.clone()).unwrap(),
        published_messages.last().unwrap().data
    );

    Ok(())
}
```],
caption: [integration test replay time frame]
)

The test starts by starting the RabbitMQ server and creating the dummy data.
The `replay_time_frame` function is called with the `from` and `to` parameters 
set to the first and last message in the queue. The `replay_time_frame` function should 
republish all messages in the queue. The returned messages are compared to the 
published messages. If the messages are equal, the test succeeds otherwise the 
test fails.
#pagebreak()
The last test checks if the `replay_transaction` function republishes the correct 
messages.
#figure(
  sourcecode()[```rs
  #[tokio::test]
async fn i_test_replay_header() -> Result<()> {
    let docker = clients::Cli::default();
    let image = GenericImage::new("rabbitmq", "3.12-management").with_wait_for(
        testcontainers::core::WaitFor::message_on_stdout("started TCP listener on [::]:5672"),
    );
    let image = image.with_exposed_port(5672).with_exposed_port(15672);
    let node = docker.run(image);
    let amqp_port = node.get_host_port_ipv4(5672);
    let management_port = node.get_host_port_ipv4(15672);

    let message_count = 500;
    let queue_name = "replay";
    let published_messages = create_dummy_data(amqp_port, message_count, queue_name).await?;
    let client = reqwest::Client::new();
    loop {
        let res = client
            .get(format!(
                "http://localhost:{}/api/queues/%2f/{}",
                management_port, queue_name
            ))
            .basic_auth("guest", Some("guest"))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
        match res.get("messages") {
            Some(m) => {
                match res.get("type") {
                    Some(t) => assert_eq!(t.as_str().unwrap(), "stream"),
                    None => panic!("type not found"),
                }
                assert_eq!(m.as_i64().unwrap(), message_count);
                break;
            }
            None => continue,
        }
    }

    let mut cfg = Config::default();
    cfg.url = Some(format!("amqp://guest:guest@localhost:{}/%2f", amqp_port));

    cfg.pool = Some(PoolConfig::new(1));

    let pool = cfg.create_pool(Some(Runtime::Tokio1)).unwrap();
    let rabbitmq_config = RabbitmqApiConfig {
        username: "guest".to_string(),
        password: "guest".to_string(),
        host: "localhost".to_string(),
        port: management_port.to_string(),
    };

    for m in published_messages {
        let header_replay = HeaderReplay {
            queue: queue_name.to_string(),
            header: rabbit_revival::AMQPHeader {
                name: "x-stream-transaction-id".to_string(),
                value: m.transaction.unwrap().value,
            },
        };
        let replayed_messages =
            rabbit_revival::replay::replay_header(&pool, &rabbitmq_config, header_replay).await?;
        assert_eq!(replayed_messages.len(), 1);
    }

    Ok(())
}
```],
caption: [integration test replay header]
)

The test starts by starting the RabbitMQ server and creating the dummy data.
The `replay_header` function is called for each message. The transaction id of the
previously published message is used as the indicator for which message should be republished.
The returned messages are compared to the published messages. If the messages are 
equal, the test succeeds otherwise the test fails.
#linebreak()
Only one unit test is present. The unit test checks if the `is_within_timeframe` method 
returns the correct result.
#figure(
  sourcecode()[```rs
  #[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};

    #[tokio::test]
    async fn test_is_within_timeframe() {
        let tests = vec![
            (
                Some(Utc.with_ymd_and_hms(2021, 10, 13, 0, 0, 0).unwrap()), 
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()), 
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(false),
            ),
            (
                Some(Utc.with_ymd_and_hms(2022, 3, 13, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()), 
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()), 
                Some(true),
            ),
            (
                Some(Utc.with_ymd_and_hms(2022, 8, 13, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()), 
                Some(true),
            ),
            (
                Some(Utc.with_ymd_and_hms(2023, 1, 13, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()), 
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(false),
            ),
            (
                Some(Utc.with_ymd_and_hms(2023, 6, 13, 0, 0, 0).unwrap()), 
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()), 
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(false),
            ),
            (
                None,
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(false),
            ),
            (None, None, None, None),
            (
                None,
                None,
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(false),
            ),
            (
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()),
                None,
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(true),
            ),
            (
                Some(Utc.with_ymd_and_hms(2022, 1, 1, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                None,                                                   
                Some(false),
            ),
            (
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                None,                                                    
                Some(true),
            ),
            (
                Some(Utc.with_ymd_and_hms(2023, 1, 1, 0, 0, 0).unwrap()),
                None,                                                   
                None,                                                  
                Some(true),
            ),
        ];
        ```],
        caption: [unit test is_within_timeframe]
    )
    #pagebreak()
    #figure(
      sourcecode()[```rs
        for (date, from, to, expected) in tests {
            assert_eq!(
                expected,
                super::is_within_timeframe(
                    date.map(|date| date.timestamp_millis() as u64),
                    from,
                    to
                )
            );
        }
    }
}
```],
caption: [unit test is_within_timeframe]
)

The test creates a vector of tuples. Each tuple contains a date, a from timestamp,
a to timestamp and the expected result. The `is_within_timeframe` method is called
for each tuple. The result is compared to the expected result. If the results are 
equal, the test succeeds otherwise the test fails.
#linebreak()

The tests can be run using the following command:
#figure(
  sourcecode()[```bash
  cargo test 
```],
caption: [run tests]
)

Resulting in the following output:
#figure(
  sourcecode()[```bash
  ❯ cargo test
Running unittests src/lib.rs (target/debug/deps/rabbit_revival-4c2723c50157660b)
running 1 test
test replay::tests::test_is_within_timeframe ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
Running tests/integration_test.rs (target/debug/deps/integration_test-5f8eb0fca711dac4)
running 4 tests
test i_test_setup ... ok
test i_test_replay_time_frame ... ok
test i_test_fetch_messsages ... ok
test i_test_replay_header ... ok
test result: ok. 4 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 47.30s
```],
caption: [test output]
)

#pagebreak()

== Container

The microservice is packaged as a container using Docker as the container 
runtime. 

#figure(
  sourcecode()[```Dockerfile
  # Build Stage 
FROM rust:1.73.0-slim-buster as builder

RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN USER=root cargo new --bin rabbit-revival
WORKDIR ./rabbit-revival
COPY ./Cargo.toml ./Cargo.toml

# Build empty app with downloaded dependencies to produce a stable image layer for next build
RUN cargo build --release

# Build web app with own code
RUN rm src/*.rs
ADD . ./
RUN rm ./target/release/deps/rabbit_revival*
RUN cargo build --release

FROM debian:buster-slim
ARG APP=/usr/src/app

RUN apt-get update && apt-get install libssl1.1 -y && rm -rf /var/lib/apt/lists/*

EXPOSE 3000

ENV TZ=Etc/UTC \
    APP_USER=appuser

RUN groupadd $APP_USER \
    && useradd -g $APP_USER $APP_USER \
    && mkdir -p ${APP}

COPY --from=builder /rabbit-revival/target/release/rabbit-revival ${APP}/rabbit-revival

RUN chown -R $APP_USER:$APP_USER ${APP}

USER $APP_USER
WORKDIR ${APP}

CMD ["./rabbit-revival"]
```],
caption: [Dockerfile]
)

#pagebreak()
The Dockerfile starts by using the official `rust:1.73.0-slim-buster` image as the base 
image. The `rust:1.73.0-slim-buster` image is based on the `debian:buster-slim` image.
The Dockerfile takes advantage of the layer caching mechanism of Docker. Docker can 
reuse layers from previous builds if the layers did not change. To use this efficiently,
the `Cargo.toml` file is copied to the image and the dependencies are downloaded.
After the dependencies are downloaded the microservice is built. With this approach,
the dependencies are only downloaded again if the `Cargo.toml` file changes.
#linebreak()
The needed dependencies for building the microservice are installed and the
binary is built. The binary is built in release mode to optimize the binary for
size and performance. In the next stage, the `debian:buster-slim` image is used
as the base image. The needed runtime dependencies are installed. The binary is
copied from the previous stage. A new user is created and the binary is marked
as executable for the given user. As entrypoint, the binary is executed.
#linebreak()
Debian was chosen because Alpine, the otherwise industry standard base image
does not integrate as easily with Rust. Alpine is based on musl libc which is
not compatible with the Rust standard library. Therefore the Rust standard
library needs to be compiled with musl libc. 
This is not a problem per se but
unnecessary work. Debian is based on glibc which is compatible with Rust.


#pagebreak()

== CI/CD

GitHub actions are used as CI/CD framework. The project has no continuous deployment 
pipeline because that is for the user of the microservice to decide. The CI part of the 
pipeline is shown below in @ci_pipeline.


#figure(
  image("./../assets/ci.svg"),
  caption: [CI pipeline],
  kind: image
)<ci_pipeline>

The CI pipeline is triggered on every push to the `master` branch if one of the 
following paths changed:
 - src/\*\*
 - Cargo.toml
 - Cargo.lock

 #figure(
   sourcecode()[```yaml
name: Rust

on:
  push:
    paths:
      - src/**
      - Cargo.toml
      - Cargo.lock

env:
  CARGO_TERM_COLOR: always

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Install stable
      uses: dtolnay/rust-toolchain@stable
    - name: Run tests
      run: cargo test --verbose
 ```],
   caption: [Automated tests],
 )

The CI pipeline runs the tests on the latest Ubuntu image. First the repository
is checked out, afterwards, the stable Rust toolchain is installed.
Lastly, the tests are run using the `cargo test` command.
#linebreak()
If one of the tests fails, the pipeline fails. If all tests pass, the pipeline 
succeeds and the job responsible for building the container is triggered.

#figure(
  sourcecode()[```yaml
name: Create and publish a Docker image
on:
  workflow_run:
    workflows: ["Rust"]
    types:
      - completed

env:
  REGISTRY: ghcr.io

jobs:
  build-and-push-image:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Log in to the Container registry
        uses: docker/login-action@65b78e6e13532edd9afa3aa52ac7964289d1a9c1
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@9ec57ed1fcdbf14dcef7dfbe97b2010124a938b7
        with:
          images: ${{ env.REGISTRY }}/${{ github.repository }}:${{ github.sha }}
      - name: Build and push Docker image
        uses: docker/build-push-action@f2a1d5e99d037542a71f64918e516c093c6f3fc4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```],
  caption: [Build container],
)

The container is built using the `docker/build-push-action` action#footnote(
  "https://docs.github.com/en/actions/publishing-packages/publishing-docker-images",
). The action is configured to build the container using the `Dockerfile` in the
root of the repository. The image is tagged using the git commit hash available
from the predefined environment variables #footnote(
  "https://docs.github.com/en/actions/reference/environment-variables#default-environment-variables",
). If the build succeeds, the container is pushed to the GitHub container
registry. The GitHub container registry is used because it is free and
integrated into GitHub. No additional authentication is needed to push to the
GitHub container registry, making it easy to use.

#pagebreak()
In contrast to the jobs triggered on push, the Dependabot job is triggered on a
schedule. The job is responsible for updating the dependencies of the
microservice. Dependabot is a service, owned and built into GitHub #footnote("https://github.com/dependabot").

#figure(
  image("./../assets/depbot.svg", width: 80%),
  caption: [Dependabot pipeline],
  kind: image 
)<dependabot_pipeline>

#figure(
  sourcecode()[```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: daily
  - package-ecosystem: cargo
    directory: /
    schedule:
      interval: daily
    ignore:
      - dependency-name: "*"
        # patch and minor updates don't matter for libraries
        # remove this ignore rule if your package has binaries
        update-types:
          - "version-update:semver-patch"
          - "version-update:semver-minor"
```],
caption: [Dependabot configuration],
)

Dependabot is configured to check for updates daily. The job is configured to
ignore patch and minor updates. If a new major version of a dependency is
released, a pull request is crated. The pull request needs to be merged 
by a maintainer.
#pagebreak()






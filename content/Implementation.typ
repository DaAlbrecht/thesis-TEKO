#import "@preview/tablex:0.0.5": tablex, cellx
#import "@preview/codelst:1.0.0": sourcecode
#show figure.where(kind: raw): set block(breakable: true)

The entire project is available on #link("https://github.com/DaAlbrecht/rabbit-revival/tree/main")[GitHub] and 
licensed under the MIT license.

== Prequesites

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
    [The microservice is written in Rust. The rust toolchain is required to build the microservice.],
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

  The replay microservice rust project is created, as a development name i choose the name "rabbit-revival". The project is created using the following command:

#figure(sourcecode(numbering: none)[```bash
  cargo new rabbit-revival
  cd rabbit-revival
  ```], caption: [create project])

 Rust does not provide a large standard library, instead it relies on third party
crates for many basic functionalities. Based on the @architecture axum is used
as a web framework, tokio is used for asyncronous runtime  and lapin is used
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
    [tokio],
    [Tokio is an asyncronous runtime],
    [axum],
    [axum is a web framework created by the tokio team],
    [lapin],
    [Lapin is a RabbitMQ client],
    [serde],
    [Serde is a serialization / deserialization framework],
    [serde_json],
    [Serde json is a serde implementation for json],
    [anyhow],
    [Anyhow is a crate for easy error handling],
    ),
    kind: table,
    caption: [overview of commonly used crates]
)

With the basic project setup done, the first task is to implement the webservice according to the openapi specification from  @openapi_specification

 == Webservice

In order to understand the implementation of the replay microservice, first some basic concepts of axum are explained.

=== Axum concepts

axum uses tower#footnote("https://docs.rs/tower/latest/tower/index.html") under the hood. Tower is a high level abstraction for
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
Since a `Service` is generic any middleware that also implements the `Service`
trait can be used allowing axum to use a large ecosystem of middleware.

axum like any other web sever needs to be able to handle multiple requests concurrently, making a webserver
inhertly asyncronous. 

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
  ```,],
  caption: [axum routing]
  )

Rust uses colored functions#footnote(
  "https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/",
) and therefore functions that call asyncronous functions need to be marked as
asyncronous aswell. Since rust does not provide an asyncronous runtime its not
possible to declare the main entrypoint with the `async` keyword. Tokio uses the
macro `#[tokio::main]` to mark allow specifying the main function as asyncronous.#footnote("https://tokio.rs/tokio/tutorial/hello-tokio")
without needing use the runtime or builder directly.

The macro transofrms the main function into the following code: 

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

In axum the routing is handled by the `Router` struct. The `Router` matches request paths to rust functions called `Handlers` based on the HTTP method filter.

#figure(
sourcecode()[```rust
let app = Router::new()
      .route("/", get(print_hello));
```],
caption: [routing]
)

Afterwards the Server is bound to a socket address and the server is started
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

To better visualize the relationship between a service and a handler the
following program is used to demonstrate their purpose.

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
method `GET`. If a request is received that matches the route the HTTP method
the function `print_hello` is called. The function returns a string that is
converted into a response by axum. The response is then sent to the client.

#sourcecode(numbering: none)[```bash
cargo run
curl 'localhost:3000'
> hello world
```]

In the example above the `print_hello` handler takes no arguments and just returns
a static string. In the openapi specification the replay microservice needs to beable to 
receive query parameters or a json body. 
#linebreak()

In axum there are `Extractors`. Extractors are used to extract data from the request.
An Extract implements *either* the `FromRequest` or the `FromRequestParts` trait.
The difference between the two is, that the `FromRequest` consumes the request body
and thus can only be used once. The `FromRequestParts` trait does not consume the
request body and can be used multiple times. 

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
the query parameters into some type that implements `Deserialize`. In this case
the query parameters are deserialized into a `HashMap<String, String>`.

#sourcecode(numbering: none)[```bash
curl 'localhost:3000?foo=hello&baz=world'
> hello world
```]

So to recap, a `Handle`r is a function that takes zero or more `Extractors` as arguments and returns something
that can be turned into a `Response`.
#linebreak()

A `Response` is every type that implements the `IntoResponse` trait. axum implements
the trait for many common types like `String`, `&str`, `Vec<u8>`, `Json` and many more.
But the real magic of axum is the following:

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
the trait gets automatically implements for the struct.

The important part is that the as stated earlier, a handler returns something that
can be turned into a `Response`. We can use this fact and instaed of returning a concrete
type like `String` or `&str` we can tell the compiler that the handler returns
something that implements the `IntoResponse` trait. with the following line:

#sourcecode(numbering: none)[```rust
async fn print_user() -> impl IntoResponse
```]

But how does our own custom type `User` implement the `IntoResponse` trait? The
anwser and beutiful part of axum is that we do not. Instead axum uses macros#footnote("https://doc.rust-lang.org/book/ch19-06-macros.html")
to automatically implement the `IntoResponse` trait for touple of different
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

For example tuples of size 0 to 16 where the first element 
implements the `StatusCode` and just like before the last element implements the 
`IntoResponse` trait while the other elements implement the `IntoResponseParts` trait.



So in conclusion, axum uses a router to match requests to handlers. `Handlers`
are functions that take zero or more `Extractors` as arguments and return
something that can be turned into a `Response`.With the help of `Extractors` and
`Responses` axum ensures runtime type safety. A `Response` is every type that
implements the `IntoResponse` trait. The `IntoResponse` trait is automatically
implemented for commonly used types aswell as different sized tuples. It is also
possible to implement the trait manually for specific use cases.

Lets check the return value from the example shown in  @IntoResponse again:

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
second element of the tuple is a `Json<User>`. In the documentation of `axum::Json`
the following implementation is shown:

#sourcecode(numbering: none)[```rust 
impl<T> IntoResponse for Json<T>
where
    T: Serialize,
```]

The `User` struct implements the `Serialize` trait, so this is also correct and the Return value
indeed implements the `IntoResponse` trait.

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

The main function is marked as asyncronous using the `#[tokio::main]` macro.
#linebreak()

The first thing the main function does is initialize tracing. Tracing is a
framework for instrumenting rust programs with structured logging and diagnostics.
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

The tracing subscriber is initialized by either set by the default
environment variable `RUST_LOG` or set to the provided default value.
#linebreak()

Afterwards axum router is created.

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
The rout has two `MethodFilter`s attached to it. The first filter matches the 
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

The function is marked as asyncronous using the `async` keyword and returns an
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

The stuct holds a pool of amqp connections, its recommended to use long lived
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

When replaying a message from the stream, the messages gets published again. The
API supports to add a uid to a custom header. Additionally, the API supports to
add a timestamp to the message. Both options are configurable using environment
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

First in the `initialize_state` function the environment variables are read.

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

Afterwards the three structs, required to initialize the state are created.

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

The handler takes two arguments. The first argument is the application state 
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
By returning a Result, the handlers can be written in a more ideomatic way and 
take advantage of the `?` operator. The `?` operator is used to propagate errors.

The problem is, axum does not know how to turn an `AppError` into a response. In
the axum examples#footnote("https://github.com/tokio-rs/axum/tree/axum-0.6.21/examples") 
there is on how to use the `anyhow` crate#footnote("https://docs.rs/anyhow/1.0.40/anyhow/") 
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
and messages in a json format aswell as a status code.

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

According to the openapi specification from the microservice shown in @openapi_specification 
the POST method supports two different kinds of schema.
#linebreak()

Two represent the two different kinds of schema, an enum is used.

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
The `#[serde(untagged)]` attribute is used to tell serde to not explicitly identify
one of the variants of the enum. Instead serde tries to deserialize the json into 
each variant in order and returns the first variant that succeeds.
#linebreak()

Without the `#[serde(untagged)]` attribute the following json body representing a timebased replay  would be invalid.

#sourcecode(numbering: none)[```json 
{
  "queue":"replay",
  "from":"2023-10-06T13:41:35.870Z",
  "to":"2023-10-09T13:41:35.883Z"
}
```]

Instead the json body would need to look like this:

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
The extractor is used to extract the json body from the request. The json body is
serialized into the `ReplayMode` enum.

#sourcecode(numbering: none)[```rust 
  async fn replay(
    app_state: State<Arc<AppState>>,
    Json(replay_mode): Json<ReplayMode>,
) -> Result<impl IntoResponse, AppError> {
```]

The `replay` handler just like the `get_messages` handler returns a ```rust
Result<impl IntoResponse, AppError>```.

In the function body serialized json body is matched against the two variants of
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
function shown in @replay_header return the messages that should be replayed.

The vector of messages is passed to the `publish_message` function shown in @publish_message.
and later the newly published messages are returned as Json aswell as a status code 200.

#figure(
  sourcecode()[```rs
    let replayed_messages = replay::publish_message(&pool, &message_options, messages).await?;
    Ok((StatusCode::OK, Json(replayed_messages)))
```],
caption: [publish and return messages]
)

#pagebreak()

== Replay component

The replay component has four key functions.

#figure(tablex(
  columns: (auto, 1fr),
  rows: (auto),
  align: (center + horizon, left),
  [*Name*],
  [*Description*],
  [fetch_messages],
  [returns a list of all messages in the queue based on the given filter],
  [publish_message],
  [publishes a list of messages to the queue],
  [replay_header],
  [returns a list of messages that contain the given header],
  [replay_time_frame],
  [returns a list of messages that are between the given timestamps],
  [get_queue_message_count],
  [returns the number of messages in the queue],
), kind: table, caption: [replay key functions])

The `fetch_messages` function gets called when the `get_messages` handler is envoked.

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
)

Each message in a stream has an offset. The offset is used to identify the
`x-stream-offset` header. The offset is optional on the `Message` struct because
the offset is only available when the message gets read from the stream. If the
message is being publshed, the publisher does not know the offset of the
message.

#linebreak()
The `#[serde(skip_serializing_if = "Option::is_none")]` attribute is used to
skip serializing the field if the field is `None`. This results in a cleaner
json response.
#linebreak()

As shown in the @MessageOptions the microservice can be configured to add a
transaction id to the message. The transaction id is added to the message as a
custom header. If this option is enabled, the `TransactionHeader` struct is
holding the name of the header and the value of the header for the specific
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

First the number of messages in the queue is fetched. 

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

The `get_queue_message_count` function is used to retrieve metadata about the
queue using the RabbitMQ management API. This is necessary because the AMQP
protocol does not provide a way to check if a queue does actually exist and if
it does exist, how many messages are in the queue. The only way to get the
number of messages in a queue using the AMQP protocol is to declare the queue
again. The problem is, if the queue already exists, the number of messages in
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

First a new http client is created. The url to the RabbitMQ management API is 
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
caption: [send GET request to RabbitMQ management API]
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

After the number of messages in the queue is known, a connection to the amqp
server is established. A channel is created and the `basic_qos` method is called
on the channel. The `basic_qos` method is used to limit the number of messages
that are being prefetched from the queue. The `basic_qos` method is called with
a prefetch count of 1000. This means that the channel will only prefetch 1000
messages from the queue. This is necessary because the queue could contain
millions of messages and the microservice should not consume all messages at
once. If the microservice would consume all messages at once, the microservice
would run out of memory if the queue contains millions of messages.

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
returns a `FieldTable`. The `FieldTable` is used to pass additional amqp
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
The problem with the consumer is, the consumer does not know when to stop
consuming messages. The consumer is a subscription based approach. The consumer 
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
redelivered to the consumer. If no message would be acknowledged, the queue 
would not send more messages than the prefetch count.

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
the queue is used to determine if the message is the last message in the queue.

#figure(
  sourcecode()[```rs
let offset = match headers.inner().get("x-stream-offset") {
    Some(AMQPValue::LongLongInt(offset)) => offset,
    _ => return Err(anyhow!("x-stream-offset not found")),
};
```],
caption: [extract offset]
)

If for some unknown reason the `x-stream-offset` header is not present, an error 
is returned.

After the offset is extracted, the timestamp is extracted from the `Delivery` and the 
function `is_within_timeframe` is called. The `is_within_timeframe` function is
used to determine if the message is within the timeframe specified by the request.

#figure(
  sourcecode()[```rs
let timestamp = *delivery.properties.timestamp();
match is_within_timeframe(timestamp, message_query.from, message_query.to) {
```],
caption: [extract timestamp and call is_within_timeframe]
)

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
    cellx(fill: rgb("#fdff32"))[None],
    cellx(fill: rgb("#fdff32"))[None],
    cellx(fill: rgb("#fdff32"))[None],
    cellx(fill: rgb("#fdff32"))[None],
    ),
  kind: table,
  caption: [is_within_timeframe matrix]
  )

The function needs to return `None` because the message does not necessarily
have a timestamp. 

#figure(
  sourcecode()[```rs
  //placeholder
```],
caption: [publish_message]
)<publish_message>

#figure(
  sourcecode()[```rs
  //placeholder
```],
caption: [replay_header]
)<replay_header>

#figure(
  sourcecode()[```rs
  //placeholder
```],
caption: [replay_time_frame]
)<replay_time_frame>

== Container

== CI/CD


#import "@preview/tablex:0.0.5": tablex, cellx
#import "@preview/codelst:1.0.0": sourcecode

The entire project is available on #link("https://github.com/DaAlbrecht/rabbit-revival/tree/main")[GitHub] and 
licensed under the MIT license.

The implementation will be explained incrementally for a complete overview of
the codebase check the github repository.

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
    [Axum is a web framework created by the tokio team],
    [lapin],
    [Lapin is a RabbitMQ client],
    [serde],
    [Serde is a serialization / deserialization framework],
    [serde_json],
    [Serde json is a serde implementation for json],
    [anyhow],
    [Anyhow is a crate for error handling],
    ),
    kind: table,
    caption: [overview of commonly used crates]
)

With the basic project setup done, the first task is to implement the webservice according to the openapi specification from  @openapi_specification

 == Webservice

In order to understand the implementation of the replay microservice, first some basic concepts of axum are explained.

=== Axum concepts

Axum uses tower#footnote("https://docs.rs/tower/latest/tower/index.html") under the hood. Tower is a high level abstraction for
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

Axum like any other web sever needs to be able to handle multiple requests concurrently, making a webserver
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
> hello world%
```]

In the example above the `print_hello` handler takes no arguments and just returns
a static string. In the openapi specification the replay microservice needs to beable to 
receive query parameters or a json body. 
#linebreak()

In Axum there are `Extractors`. Extractors are used to extract data from the request.
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
> hello world%
```]

So to recap, a `Handle`r is a function that takes zero or more `Extractors` as arguments and returns something
that can be turned into a `Response`.
#linebreak()

A `Response` is every type that implements the `IntoResponse` trait. Axum implements
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
{"name":"Bob","age":20}%
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

First two handlers are created, one for the `GET` method and one for the `POST` method.
Both handlers are registered under the same path `/`.

#figure(
  sourcecode()[```rust 
  #[tokio::main]
async fn main() {

    let app = Router::new()
        .route("/", get(get_messages).post(replay));

    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```],
)

In the openapi specification the replay GET method supports two different schemas.
To represent the two different schemas the following enum is created:

#figure(sourcecode()[```rust
#[derive(serde::Deserialize, Debug)]
#[serde(untagged)]
enum ReplayMode {
    Timeframe(Timeframe),
    Transaction(Transaction),
}
```])
The enum should not be visible in the serialized json, therefore the
`#[serde(untagged)]` attribute is used. The `#[serde(untagged)]` attribute tells
serde to not wrap the enum in a json object. Instead the enum is serialized as
if it was a single field.

The `ReplayMode` enum holds two different variants representing the two different
schemas. Each variant holds a struct containing the fields of the schema.


== Replay component

== Container

== CI/CD


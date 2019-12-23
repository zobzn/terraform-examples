
# https://www.terraform.io/docs/configuration/expressions.html#string-templates

data "http" "httpbin" {
  url = "https://httpbin.org/get"

  request_headers = {
    Accept = "application/json"
  }
}

data "archive_file" "ho-he-zip" {
  type        = "zip"
  output_path = "${path.module}/res/ho-he.zip"

  source {
    filename = "хо/хо.txt"
    content  = "хо-хо-хо"
  }

  source {
    filename = "хе/хе.txt"
    content  = "хе-хе-хе"
  }
}

resource "local_file" "backends-txt" {
  filename = "${path.module}/res/backends.txt"
  content = templatefile("${path.module}/src/backends.tpl", {
    ip_addrs = ["10.0.0.1", "10.0.0.2"],
    port     = 8080
  })
}

resource "local_file" "hello-json" {
  filename = "${path.module}/res/hello.json"
  content = jsonencode({
    hello = "world"
    array = [
      { title = "*" },
      { title = "ы" }
    ]
  })
}

resource "local_file" "httpbin-json" {
  filename = "${path.module}/res/httpbin.json"
  content  = data.http.httpbin.body
}

output "backends-txt-content" {
  value = "\n${local_file.backends-txt.content}"
}

output "hello-json-content" {
  value = "\n${local_file.hello-json.content}"
}

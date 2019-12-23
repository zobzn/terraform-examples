exports.handler = (event, context, callback) => {
  console.log("Hello, logs!");

  // callback(null, "great success");
  callback(null, {
    statusCode: 200,
    body: JSON.stringify({
      message: "Hello from AWS Lambda!"
    })
  });
};

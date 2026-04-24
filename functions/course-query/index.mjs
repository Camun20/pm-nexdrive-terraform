import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://main.d3dhvqli97edsu.amplifyapp.com",
  "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
  "Access-Control-Allow-Methods": "GET,OPTIONS,POST,PUT,DELETE",
  "Access-Control-Allow-Credentials": "true"
};

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 200, headers: CORS_HEADERS, body: "" };
  }

  const { httpMethod, path, queryStringParameters } = event;
  const COURSES_TABLE = process.env.COURSES_TABLE;
  const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE;

  try {
    if (path === "/courses") {
      if (httpMethod === "GET") {
        const command = new ScanCommand({ TableName: COURSES_TABLE });
        const response = await docClient.send(command);
        
        let courses = response.Items || [];
        
        try {
          if (EVALUATIONS_TABLE) {
            const evalsCommand = new ScanCommand({ TableName: EVALUATIONS_TABLE });
            const evalsResponse = await docClient.send(evalsCommand);
            const evals = evalsResponse.Items || [];
            
            courses = courses.map(course => {
              const hasQuestions = evals.some(e => e.courseId === course.courseId);
              return { ...course, hasQuestions };
            });
          }
        } catch(e) {
          console.error("Error fetching evaluations for courses:", e);
        }

        return {
          statusCode: 200,
          headers: CORS_HEADERS,
          body: JSON.stringify(courses)
        };
      }
    }

    if (path === "/content") {
      const courseId = queryStringParameters?.courseId;
      if (!courseId) {
        return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ message: "Missing courseId" }) };
      }

      const command = new ScanCommand({
        TableName: EVALUATIONS_TABLE,
        FilterExpression: "courseId = :cid",
        ExpressionAttributeValues: { ":cid": courseId }
      });
      const response = await docClient.send(command);

      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify({ evaluations: response.Items })
      };
    }

    return {
      statusCode: 404,
      headers: CORS_HEADERS,
      body: JSON.stringify({ message: "Not Found" })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ message: "Internal Server Error", error: error.message })
    };
  }
};

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  const { httpMethod, path, pathParameters, queryStringParameters } = event;
  const COURSES_TABLE = process.env.COURSES_TABLE;
  const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE;

  try {
    if (path === "/courses") {
      if (httpMethod === "GET") {
        // List all courses
        const command = new ScanCommand({ TableName: COURSES_TABLE });
        const response = await docClient.send(command);
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify(response.Items)
        };
      }
    }

    if (path === "/content") {
      // Logic for fetching specific course content or evaluations
      const courseId = queryStringParameters?.courseId;
      if (!courseId) {
        return { statusCode: 400, body: JSON.stringify({ message: "Missing courseId" }) };
      }

      // Fetch evaluations for this course
      const command = new ScanCommand({
        TableName: EVALUATIONS_TABLE,
        FilterExpression: "courseId = :cid",
        ExpressionAttributeValues: { ":cid": courseId }
      });
      const response = await docClient.send(command);

      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        body: JSON.stringify({ evaluations: response.Items })
      };
    }

    return {
      statusCode: 404,
      body: JSON.stringify({ message: "Not Found" })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal Server Error", error: error.message })
    };
  }
};

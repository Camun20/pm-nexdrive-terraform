import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, ScanCommand, GetCommand } from "@aws-sdk/lib-dynamodb";
import { CognitoIdentityProviderClient, ListUsersCommand } from "@aws-sdk/client-cognito-identity-provider";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const cognitoClient = new CognitoIdentityProviderClient({});

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  const { httpMethod, path, body } = event;
  
  const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;
  const USER_POOL_ID = process.env.USER_POOL_ID;

  try {
    if (httpMethod === "POST" && path === "/users") {
      // Logic for listing or registering users
      // If body exists, maybe it's for assigning a course or registering
      const parsedBody = body ? JSON.parse(body) : {};
      
      if (parsedBody.action === "list") {
        const command = new ListUsersCommand({ UserPoolId: USER_POOL_ID });
        const response = await cognitoClient.send(command);
        
        // Enrich with DynamoDB data if needed
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify(response.Users)
        };
      }

      if (parsedBody.action === "assignCourse") {
        const { userId, courseId } = parsedBody;
        const command = new PutCommand({
          TableName: DYNAMODB_TABLE,
          Item: {
            PK: `USER#${userId}`,
            SK: `COURSE#${courseId}`,
            userId,
            courseId,
            assignedAt: new Date().toISOString(),
            status: "IN_PROGRESS",
            progress: 0
          }
        });
        await docClient.send(command);
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify({ message: "Course assigned successfully" })
        };
      }
    }

    return {
      statusCode: 400,
      body: JSON.stringify({ message: "Unsupported method or path" })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal Server Error", error: error.message })
    };
  }
};

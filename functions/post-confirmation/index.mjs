import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
  console.log("PostConfirmation Event:", JSON.stringify(event));

  const { userName, request } = event;
  const { userAttributes } = request;
  const email = userAttributes.email;
  const name = userAttributes.name || userName;

  const USERS_TABLE = process.env.USERS_DATA_TABLE;

  try {
    await docClient.send(new PutCommand({
      TableName: USERS_TABLE,
      Item: {
        email: email,
        name: name,
        assignedCourses: [],
        progressStatus: "Iniciado",
        createdAt: new Date().toISOString()
      }
    }));
    console.log(`User ${email} synced to DynamoDB.`);
  } catch (error) {
    console.error("Error syncing user to DynamoDB:", error);
    // Even if sync fails, we return the event so Cognito doesn't block the user
  }

  return event;
};

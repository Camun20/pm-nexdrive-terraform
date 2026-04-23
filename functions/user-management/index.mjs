import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, ScanCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { CognitoIdentityProviderClient, ListUsersCommand, AdminDeleteUserCommand } from "@aws-sdk/client-cognito-identity-provider";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const cognitoClient = new CognitoIdentityProviderClient({});

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  const { httpMethod, path, body } = event;
  
  const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE; // Metadata table
  const COURSES_TABLE = process.env.COURSES_TABLE;
  const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE;
  const USER_POOL_ID = process.env.USER_POOL_ID;

  try {
    if (httpMethod === "POST" && path === "/users") {
      const parsedBody = body ? JSON.parse(body) : {};
      
      // 1. LIST USERS
      if (parsedBody.action === "list") {
        const command = new ListUsersCommand({ UserPoolId: USER_POOL_ID });
        const response = await cognitoClient.send(command);
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify(response.Users)
        };
      }

      // 2. GET STATS
      if (parsedBody.action === "getStats") {
        const cognitoResp = await cognitoClient.send(new ListUsersCommand({ UserPoolId: USER_POOL_ID }));
        const coursesResp = await docClient.send(new ScanCommand({ TableName: COURSES_TABLE, Select: "COUNT" }));
        
        // Count certificates (Items in Metadata table where SK starts with CERT#)
        const certsResp = await docClient.send(new ScanCommand({ 
          TableName: DYNAMODB_TABLE, 
          FilterExpression: "begins_with(SK, :cert)",
          ExpressionAttributeValues: { ":cert": "CERT#" },
          Select: "COUNT"
        }));

        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify({
            totalStudents: cognitoResp.Users?.length || 0,
            activeCourses: coursesResp.Count || 0,
            certificatesIssued: certsResp.Count || 0
          })
        };
      }

      // 3. DELETE USER
      if (parsedBody.action === "deleteUser") {
        const { userId, email } = parsedBody;
        
        // Delete from Cognito
        await cognitoClient.send(new AdminDeleteUserCommand({
          UserPoolId: USER_POOL_ID,
          Username: userId
        }));

        // Delete metadata from DynamoDB (all items for this user)
        const userItems = await docClient.send(new ScanCommand({
          TableName: DYNAMODB_TABLE,
          FilterExpression: "PK = :pk",
          ExpressionAttributeValues: { ":pk": `USER#${userId}` }
        }));

        for (const item of (userItems.Items || [])) {
          await docClient.send(new DeleteCommand({
            TableName: DYNAMODB_TABLE,
            Key: { PK: item.PK, SK: item.SK }
          }));
        }

        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify({ message: "User deleted from Cognito and DynamoDB" })
        };
      }

      // 4. ASSIGN COURSE
      if (parsedBody.action === "assignCourse") {
        const { userId, courseId } = parsedBody;
        await docClient.send(new PutCommand({
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
        }));
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          body: JSON.stringify({ message: "Course assigned successfully" })
        };
      }
    }

    return {
      statusCode: 400,
      body: JSON.stringify({ message: "Unsupported method or action" })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal Server Error", error: error.message })
    };
  }
};

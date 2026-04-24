import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, DeleteCommand, PutCommand, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { CognitoIdentityProviderClient, AdminDeleteUserCommand } from "@aws-sdk/client-cognito-identity-provider";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const cognitoClient = new CognitoIdentityProviderClient({});

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://main.d3dhvqli97edsu.amplifyapp.com",
  "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
  "Access-Control-Allow-Methods": "GET,OPTIONS,POST,PUT,DELETE",
  "Access-Control-Allow-Credentials": "true"
};

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  const { httpMethod, path, body } = event;
  
  const USERS_DATA_TABLE = process.env.USERS_DATA_TABLE;

  try {
    // OPTIONS for CORS preflight
    if (httpMethod === "OPTIONS") {
      return { statusCode: 200, headers: CORS_HEADERS, body: "" };
    }

    const parsedBody = body ? JSON.parse(body) : {};

    // POST /users - Multi-action handler
    if (httpMethod === "POST" && path === "/users") {
      const { action, email, name, userId, courseId } = parsedBody;

      // List Users
      if (action === "list") {
        const result = await docClient.send(new ScanCommand({
          TableName: USERS_DATA_TABLE
        }));
        return {
          statusCode: 200,
          headers: CORS_HEADERS,
          body: JSON.stringify(result.Items || [])
        };
      }

      // Delete User
      if (action === "deleteUser") {
        await docClient.send(new DeleteCommand({
          TableName: USERS_DATA_TABLE,
          Key: { email }
        }));
        
        try {
          const USER_POOL_ID = process.env.USER_POOL_ID;
          if (USER_POOL_ID) {
            await cognitoClient.send(new AdminDeleteUserCommand({
              UserPoolId: USER_POOL_ID,
              Username: email
            }));
          }
        } catch (cognitoError) {
          console.error("Error deleting user from Cognito:", cognitoError);
        }

        return {
          statusCode: 200,
          headers: CORS_HEADERS,
          body: JSON.stringify({ message: "User deleted" })
        };
      }

      // Assign Courses
      if (action === "assignCourses") {
        const { email, assignedCourses } = parsedBody;
        await docClient.send(new UpdateCommand({
          TableName: USERS_DATA_TABLE,
          Key: { email },
          UpdateExpression: "SET assignedCourses = :ac, updatedAt = :ua",
          ExpressionAttributeValues: {
            ":ac": assignedCourses || [],
            ":ua": new Date().toISOString()
          }
        }));
        return {
          statusCode: 200,
          headers: CORS_HEADERS,
          body: JSON.stringify({ message: "Cursos asignados correctamente" })
        };
      }

      // Get Stats
      if (action === "getStats") {
        const COURSES_TABLE = process.env.COURSES_TABLE;
        const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE;

        const usersResult = await docClient.send(new ScanCommand({
          TableName: USERS_DATA_TABLE
        }));
        
        let totalCourses = 0;
        let totalEvaluations = 0;
        
        if (COURSES_TABLE) {
          const coursesResult = await docClient.send(new ScanCommand({ TableName: COURSES_TABLE }));
          totalCourses = coursesResult.Items ? coursesResult.Items.length : 0;
        }
        
        if (EVALUATIONS_TABLE) {
          const evalsResult = await docClient.send(new ScanCommand({ TableName: EVALUATIONS_TABLE }));
          totalEvaluations = evalsResult.Items ? evalsResult.Items.length : 0;
        }

        const items = usersResult.Items || [];
        return {
          statusCode: 200,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            totalUsers: items.length,
            activeUsers: items.filter(u => u.progressStatus !== "Terminado").length,
            completedUsers: items.filter(u => u.progressStatus === "Terminado").length,
            totalCourses: totalCourses,
            totalEvaluations: totalEvaluations
          })
        };
      }
      
      // Save/Update User
      if (action === "save" || !action) {
         await docClient.send(new PutCommand({
          TableName: USERS_DATA_TABLE,
          Item: {
            email: email,
            name: name,
            assignedCourses: [],
            progressStatus: "Iniciado",
            updatedAt: new Date().toISOString()
          }
        }));
        return {
          statusCode: 200,
          headers: CORS_HEADERS,
          body: JSON.stringify({ message: "User saved" })
        };
      }
    }

    // Fallback for GET /users
    if (httpMethod === "GET" && path === "/users") {
      const result = await docClient.send(new ScanCommand({
        TableName: USERS_DATA_TABLE
      }));
      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify(result.Items || [])
      };
    }

    return {
      statusCode: 404,
      headers: CORS_HEADERS,
      body: JSON.stringify({ message: "Not Found" })
    };

  } catch (error) {
    console.error("Error:", error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ message: error.message })
    };
  }
};

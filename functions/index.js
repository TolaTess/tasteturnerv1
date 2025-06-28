/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require('firebase-functions/params');
const { startOfWeek, endOfWeek, format } = require("date-fns");

admin.initializeApp();

// Initialize the Gemini client with the API key from function configuration
const genAI = new GoogleGenerativeAI(functions.config().gemini.key);
const firestore = getFirestore();

// Helper to get week number
function _getWeek(date) {
  const d = new Date(
    Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
  );
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

/**
 * A scheduled Cloud Function that generates new ingredients for the weekly battle.
 * - Runs every Monday at 1:00 AM.
 * - Generates two ingredients using the Gemini API.
 * - Updates the 'general' battle document in Firestore with the new battle data.
 */
exports.generateBattleIngredients = functions.pubsub
  .schedule("every monday 01:00")
  .timeZone("America/New_York") // IMPORTANT: Set to your preferred timezone
  .onRun(async (context) => {
    console.log("Running weekly ingredient generation job.");

    try {
      // 1. Generate ingredients with Gemini. Retry logic added for robustness.
      let ingredientsData = [];
      let attempts = 0;
      const maxAttempts = 3;

      while (ingredientsData.length < 2 && attempts < maxAttempts) {
        attempts++;
        console.log(`Attempt ${attempts} to generate and find ingredients.`);
        
        const model = genAI.getGenerativeModel({ model: "gemini-pro" });
        const prompt =
          "Give me two common cooking ingredients that can be paired together for a cooking challenge. They should be relatively easy to find. Return them as a simple comma-separated list, for example: 'Chicken Breast, Broccoli'. Do not add any other text, formatting, or quotation marks.";

        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();
        const ingredientNames = text.split(",").map((item) => item.trim());

        if (ingredientNames.length < 2) {
          console.log(
            `Gemini did not return two ingredients. Raw response: "${text}"`
          );
          continue; // Try again
        }

        // 2. Look up ingredients in Firestore
        const ingredientsRef = firestore.collection("ingredients");
        const foundIngredients = [];

        for (const name of ingredientNames) {
          // Use .toLowerCase() for case-insensitive matching
          const snapshot = await ingredientsRef
            .where("name", "==", name.toLowerCase())
            .limit(1)
            .get();
          
          if (!snapshot.empty) {
            const doc = snapshot.docs[0];
            foundIngredients.push({
              id: doc.id,
              name: doc.data().name, // Use the canonical name from DB
              image: doc.data().image,
            });
          } else {
            console.log(`Ingredient "${name}" not found in Firestore.`);
          }
        }
        
        if(foundIngredients.length === 2) {
            ingredientsData = foundIngredients;
        }
      }

      if (ingredientsData.length < 2) {
          console.error("Failed to find two valid ingredients after several attempts. Aborting.");
          return null;
      }

      console.log(`Found ingredients in Firestore:`, ingredientsData);

      // 3. Prepare data for Firestore update
      const battleRef = firestore.collection("battles").doc("general");

      // Calculate date keys
      const today = new Date();
      const battleDateKey = `${today.getFullYear()}-${String(
        today.getMonth() + 1
      ).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
      
      const deadline = new Date(today);
      deadline.setDate(today.getDate() + 6); // Deadline is Sunday

      // Find the most recent battle date to set as 'prevBattle'
      const battleDoc = await battleRef.get();
      let prevBattleKey = null;
      if (battleDoc.exists && battleDoc.data().dates) {
        const dateKeys = Object.keys(battleDoc.data().dates);
        dateKeys.sort(); // Sort dates chronologically
        prevBattleKey = dateKeys.pop(); // Get the most recent one
      }
      
      // 4. Construct the update payload to create the new battle week
      const newBattlePayload = {
        [`dates.${battleDateKey}`]: {
          ingredients: ingredientsData,
          participants: {},
          voted: [],
          status: "active",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          battleDeadline: admin.firestore.Timestamp.fromDate(deadline),
        },
      };
      await battleRef.set(newBattlePayload, { merge: true });

      // 5. Update the main 'general/data' document with the new week's state
      const generalDataRef = firestore.collection("general").doc("data");
      await generalDataRef.set({
          currentBattle: battleDateKey,
          prevBattle: prevBattleKey,
          battleDeadline: admin.firestore.Timestamp.fromDate(deadline)
      }, { merge: true });

      console.log(`Successfully created new battle for date: ${battleDateKey}`);
      return null;
    } catch (error) {
      console.error("Error generating battle ingredients:", error);
      return null;
    }
  });

/**
 * A scheduled Cloud Function that processes the end of a battle.
 * - Runs every Monday at 12:30 AM.
 * - Finds the most recently concluded battle.
 * - Calculates winners based on votes.
 * - Awards points to winners.
 * - Saves a record of the winners.
 */
exports.processBattleEnd = functions.pubsub
  .schedule("every monday 00:30")
  .timeZone("America/New_York") // IMPORTANT: Set to your preferred timezone
  .onRun(async (context) => {
    console.log("Running weekly battle processing job.");

    try {
      const generalDataRef = firestore.collection("general").doc("data");
      const generalDataDoc = await generalDataRef.get();
      // Use currentBattle, as this is the one that is ending.
      const battleKeyToProcess = generalDataDoc.data()?.currentBattle;

      if (!battleKeyToProcess) {
        console.log("No current battle key found. Nothing to process.");
        return null;
      }

      // 1. Get the battle data that just ended
      const battleRef = firestore.collection("battles").doc("general");
      const battleDoc = await battleRef.get();

      if (
        !battleDoc.exists ||
        !battleDoc.data().dates ||
        !battleDoc.data().dates[battleKeyToProcess]
      ) {
        console.error(`Data for previous battle ${battleKeyToProcess} not found.`);
        return null;
      }

      const battleData = battleDoc.data().dates[battleKeyToProcess];
      const participants = battleData.participants || {};

      // Mark battle as ended regardless of participant count
      await battleRef.update({
        [`dates.${battleKeyToProcess}.status`]: "ended",
      });

      if (Object.keys(participants).length < 2) {
        console.log("Not enough participants to determine a winner. Battle marked as ended.");
        return null;
      }

      // 2. Calculate winners
      const sortedParticipants = Object.entries(participants)
        .map(([userId, data]) => ({
          userId,
          votes: (data.votes || []).length,
        }))
        .sort((a, b) => b.votes - a.votes);
      
      const winners = sortedParticipants.slice(0, 2); // Top 2 winners

      // 3. Award points and save winner records
      const winnersToSave = {};
      const pointsToAward = [30, 20]; // 1st, 2nd

      for (let i = 0; i < winners.length; i++) {
        const winner = winners[i];
        const points = pointsToAward[i];
        
        // Update points
        const userPointsRef = firestore.collection("points").doc(winner.userId);
        await firestore.runTransaction(async (transaction) => {
            const userPointsDoc = await transaction.get(userPointsRef);
            const currentPoints = userPointsDoc.exists ? userPointsDoc.data().points : 0;
            transaction.set(userPointsRef, { points: currentPoints + points }, { merge: true });
        });

        // Add to winners list for historical record
        winnersToSave[winner.userId] = {
            position: i + 1,
            votes: winner.votes,
            pointsAwarded: points,
        };
      }

      const weekId = `week_${battleKeyToProcess}`;
      await firestore.collection("winners").doc(weekId).set({
          date: battleKeyToProcess,
          winners: winnersToSave,
      });

      // 4. Update the announcement date to today
      const today = new Date();
      const announceDateString = `${today.getFullYear()}-${String(
        today.getMonth() + 1
      ).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

      await generalDataRef.update({
        isAnnounceDate: announceDateString,
      });

      await generalDataRef.set(
        {
          announcement: {
            date: announceDateString,
            type: "battleWinner",
            winnerId: winners[0]?.userId, // Store the first winner's ID
          },
        },
        { merge: true }
      );

      console.log(
        `Successfully processed battle ${battleKeyToProcess} and awarded points.`
      );
      return null;
    } catch (error) {
      console.error("Error processing battle end:", error);
      return null;
    }
  });

/**
 * A Firestore-triggered Cloud Function that automatically calculates and updates
 * a user's total daily nutritional intake whenever a meal is added, updated,
 * or deleted for that day.
 * - Listens for writes on 'userMeals/{userId}/meals/{date}'.
 * - Fetches all meals for that specific day.
 * - Sums up the nutritional values (calories, protein, carbs, fat).
 * - Writes the aggregated data to 'users/{userId}/daily_summary/{date}'.
 */
exports.calculateDailyNutrition = functions.firestore
  .document("userMeals/{userId}/meals/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    console.log(
      `--- Function calculateDailyNutrition triggered for user: ${userId} on date: ${date} ---`
    );

    // If the document is deleted, remove the summary
    if (!change.after.exists) {
      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);
      await summaryDocRef.delete();
      console.log(
        `Document at userMeals/.../${date} deleted. Removed summary at: ${summaryDocRef.path}`
      );
      return null;
    }

    const data = change.after.data();
    // The 'meals' field is a map, not an array. We need to extract the items.
    const mealsMap = data.meals || {};
    let allMealItems = [];

    // Check if mealsMap is an object and not empty
    if (typeof mealsMap === "object" && Object.keys(mealsMap).length > 0) {
      // It's a map of maps, e.g., { "Add Food": { "0": { meal_data } } }
      // We iterate over the values of the outer map
      Object.values(mealsMap).forEach((innerMap) => {
        // Then iterate over the values of the inner map to get the meal items
        if (typeof innerMap === "object") {
          allMealItems.push(...Object.values(innerMap));
        }
      });
    }

    console.log(`Found ${allMealItems.length} total meal items to process.`);

    if (allMealItems.length === 0) {
      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);
      await summaryDocRef.delete();
      console.log(
        `Meals data is empty or invalid. Deleted daily summary at: ${summaryDocRef.path}`
      );
      return null;
    }

    try {
      let totalCalories = 0;
      let totalProtein = 0;
      let totalCarbs = 0;
      let totalFat = 0;
      const mealTotals = {
        Breakfast: 0,
        Lunch: 0,
        Dinner: 0,
        Snacks: 0,
      };

      // Loop over meal types ("Breakfast", "Add Food", etc.)
      for (const mealTypeKey in mealsMap) {
        if (Object.prototype.hasOwnProperty.call(mealsMap, mealTypeKey)) {
          const innerMap = mealsMap[mealTypeKey];

          if (typeof innerMap === "object" && innerMap !== null) {
            // Loop over individual food items (e.g., "0", "1")
            for (const itemKey in innerMap) {
              if (Object.prototype.hasOwnProperty.call(innerMap, itemKey)) {
                const item = innerMap[itemKey];

                if (item && typeof item === "object") {
                  const calories =
                    typeof item.calories === "number" ? item.calories : 0;

                  // Add to grand totals
                  totalCalories += calories;
                  totalProtein +=
                    typeof item.protein === "number" ? item.protein : 0;
                  totalCarbs +=
                    typeof item.carbs === "number" ? item.carbs : 0;
                  totalFat += typeof item.fat === "number" ? item.fat : 0;

                  // Add to meal-specific totals
                  if (mealTotals.hasOwnProperty(mealTypeKey)) {
                    mealTotals[mealTypeKey] += calories;
                  } else {
                    // Any non-standard meal type goes into 'Add Food'
                    if (!mealTotals["Add Food"]) {
                      mealTotals["Add Food"] = 0;
                    }
                    mealTotals["Add Food"] += calories;
                  }
                }
              }
            }
          }
        }
      }

      const dailySummaryData = {
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        mealTotals,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };

      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);

      await summaryDocRef.set(dailySummaryData, { merge: true });

      console.log(
        `Successfully updated daily summary for user ${userId} on ${date}.`
      );
      console.log("Updated data:", dailySummaryData);
      console.log("--- Function calculateDailyNutrition finished ---");
      return null;
    } catch (error) {
      console.error(
        `Error calculating daily nutrition for user ${userId} on ${date}:`,
        error
      );
      console.error("--- Function calculateDailyNutrition ERRORED ---");
      return null;
    }
  });

/**
 * Triggered when a user's meal for a specific day is created or updated.
 * It reads all meals for the week, aggregates the ingredients, and
 * updates the weekly shopping list for that user in the specified format.
 */
exports.generateAndSaveWeeklyShoppingList = functions.firestore
  .document("mealPlans/{userId}/date/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    console.log(
      `--- Running Shopping List Generation for user: ${userId} on date: ${date} ---`
    );

    try {
      // 1. Determine the week for the changed meal using the same logic as the test function
      const mealDate = new Date(date);
      const year = mealDate.getUTCFullYear();
      const week = _getWeek(mealDate);
      const weekId = `week_${year}-${String(week).padStart(2, "0")}`;

      // 2. Fetch all meal plan documents for the entire week
      const weekStart = startOfWeek(mealDate, { weekStartsOn: 0 }); // Sunday
      const weekEnd = endOfWeek(mealDate, { weekStartsOn: 0 });

      const startDateStr = format(weekStart, "yyyy-MM-dd");
      const endDateStr = format(weekEnd, "yyyy-MM-dd");

      console.log(
        `Querying for meal plans between: ${startDateStr} and ${endDateStr}`
      );

      const mealsSnapshot = await firestore
        .collection(`mealPlans/${userId}/date`)
        .where(admin.firestore.FieldPath.documentId(), ">=", startDateStr)
        .where(admin.firestore.FieldPath.documentId(), "<=", endDateStr)
        .get();

      console.log(
        `Found ${mealsSnapshot.size} meal plan document(s) for the week.`
      );

      // 3. Collect all unique meal IDs from the documents
      const allMealIds = new Set();
      mealsSnapshot.forEach((dayDoc) => {
        const data = dayDoc.data();
        const mealPaths = data.meals || [];
        mealPaths.forEach((path) => {
          const mealId = path.split("/")[0];
          if (mealId) allMealIds.add(mealId);
        });
      });

      // If no meals are found for the week, clear the generated items and exit
      if (allMealIds.size === 0) {
        console.log("No meal IDs found for the week. Clearing generated list.");
        const listRef = firestore
          .collection("userMeals")
          .doc(userId)
          .collection("shoppingList")
          .doc(weekId);
        // Use set with merge to only clear the generatedItems field
        await listRef.set({ generatedItems: {} }, { merge: true });
        return null;
      }

      // Fetch all unique meal documents from the 'meals' collection
      const mealDocs = await firestore
        .collection("meals")
        .where(admin.firestore.FieldPath.documentId(), "in", [...allMealIds])
        .get();

      // Aggregate the ingredients from these meals
      const weeklyIngredients = {};
      for (const mealDoc of mealDocs.docs) {
        const mealData = mealDoc.data();
        const ingredients = mealData.ingredients || {};
        for (const [name, amountStr] of Object.entries(ingredients)) {
          const quantityMatch = (amountStr || "").match(/^(\d+(\.\d+)?)/);
          const unitMatch = (amountStr || "").match(/[a-zA-Z\s]+$/);
          const quantity = quantityMatch ? Number(quantityMatch[1]) : 0;
          const unit = unitMatch ? unitMatch[0].trim() : "";

          if (name && quantity > 0) {
            if (!weeklyIngredients[name]) {
              weeklyIngredients[name] = { quantity: 0, unit: unit };
            }
            weeklyIngredients[name].quantity += quantity;
          }
        }
      }

      // 4. Find existing ingredients or create new ones, then build the map
      const requiredItems = {};
      for (const name in weeklyIngredients) {
        const { quantity, unit } = weeklyIngredients[name];
        const ingredientsRef = firestore.collection("ingredients");
        let ingredientId = null;

        const snapshot = await ingredientsRef
          .where("title", "==", name)
          .limit(1)
          .get();

        if (!snapshot.empty) {
          ingredientId = snapshot.docs[0].id;
        } else {
          console.log(`Ingredient "${name}" not found. Generating...`);
          ingredientId = await _generateAndSaveIngredient(name);
        }

        if (ingredientId) {
          const key = `${ingredientId}/${quantity}${unit}`;
          requiredItems[key] = false; // Default to false
        }
      }

      // 5. Use a transaction to safely merge the new list with the existing one
      const listRef = firestore
        .collection("userMeals")
        .doc(userId)
        .collection("shoppingList")
        .doc(weekId);

      await firestore.runTransaction(async (transaction) => {
        const doc = await transaction.get(listRef);
        const existingGeneratedItems = doc.data()?.generatedItems || {};
        const newGeneratedItems = {};

        // Preserve the status of existing items.
        // Add new items with a default status of 'false'.
        // Items no longer in the plan are implicitly removed.
        for (const key in requiredItems) {
            newGeneratedItems[key] = existingGeneratedItems[key] || false;
        }

        transaction.set(
          listRef,
          {
            generatedItems: newGeneratedItems,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true } // Merge to avoid overwriting 'manualItems'
        );
      });

      console.log(
        `Successfully updated shopping list for user ${userId}, week ${weekId}`
      );
      return null;
    } catch (error) {
      console.error("Error generating shopping list:", error);
      return null;
    }
  });

/**
 * Helper function to generate details for an ingredient using Gemini and save it.
 * It uses .add() to create an auto-generated ID.
 * @param {string} ingredientName The name of the ingredient.
 * @returns {Promise<string|null>} The new ingredient's document ID or null.
 */
async function _generateAndSaveIngredient(ingredientName) {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });
    const prompt = `
      Generate a detailed JSON object for the ingredient "${ingredientName}".
      The JSON object must match this structure:
      {
        "title": "${ingredientName}",
        "type": "...",
        "mediaPaths": [],
        "calories": ...,
        "macros": {"protein": ..., "carbs": ..., "fat": ...},
        "categories": [],
        "features": {},
        "techniques": [],
        "storageOptions": {},
        "isAntiInflammatory": ...,
        "alt": []
      }
      Do not include any text, markdown, or formatting outside of the JSON object itself.
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text().replace(/```json|```/g, "").trim();
    const ingredientData = JSON.parse(text);

    ingredientData.createdAt = admin.firestore.FieldValue.serverTimestamp();

    const newIngredientRef = await firestore.collection("ingredients").add(ingredientData);
    
    console.log(`Successfully generated and saved new ingredient: ${ingredientData.title} (ID: ${newIngredientRef.id})`);
    return newIngredientRef.id;

  } catch (error) {
    console.error(`Error generating details for "${ingredientName}":`, error);
    return null;
  }
}

/**
 * An on-call Cloud Function that allows a user to manually add a BATCH of
 * ingredients to their weekly shopping list.
 * - This is for features like the "spin wheel" that generate a list of items.
 * - Items are stored in the 'manualItems' map.
 */
exports.addManualItemsToShoppingList = functions.https.onCall(
  async (data, context) => {
    // 1. Validate call
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    if (!data.items || !Array.isArray(data.items) || data.items.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a non-empty 'items' array."
      );
    }

    const userId = context.auth.uid;
    const itemsToAdd = data.items; // e.g., [{ingredientId: 'X', amount: 'Y'}, ...]
    console.log(`Manual batch add for user ${userId}:`, itemsToAdd);

    try {
      // 2. Determine the current week ID
      const today = new Date();
      const year = today.getUTCFullYear();
      const weekNo = _getWeek(today);
      const weekId = `week_${year}-${String(weekNo).padStart(2, "0")}`;

      const listRef = firestore
        .collection("userMeals")
        .doc(userId)
        .collection("shoppingList")
        .doc(weekId);

      // 3. Use a transaction to safely read, modify, and write the map.
      await firestore.runTransaction(async (transaction) => {
        const doc = await transaction.get(listRef);
        const existingData = doc.data() || {};
        const manualItems = existingData.manualItems || {};

        itemsToAdd.forEach((item) => {
          const { ingredientId, amount } = item;
          if (ingredientId) {
            const key = amount ? `${ingredientId}/${amount}` : ingredientId;
            manualItems[key] = false; // Add new items as not purchased
          }
        });

        if (Object.keys(manualItems).length === 0) {
          console.log("No valid items to add.");
          return; // Don't write if there's nothing to write
        }

        // Write the entire updated map back.
        transaction.set(
          listRef,
          {
            manualItems, // This contains old and new items
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true } // Merge to avoid overwriting 'generatedItems'
        );
      });

      console.log(
        `Successfully added batch of manual items for user ${userId}`
      );
      return { status: "success" };
    } catch (error) {
      console.error("Error adding manual items batch:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while adding items to the shopping list."
      );
    }
  }
);

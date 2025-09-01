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

// Initialize the Gemini client with the API key from function configuration (needed for _generateAndSaveIngredient)
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

    // Also fetch water and steps data from userMeals
    let waterData = null;
    let stepsData = null;
    try {
      const userMealsDocRef = firestore
        .collection("userMeals")
        .doc(userId)
        .collection("meals")
        .doc(date);
      
      const userMealsDoc = await userMealsDocRef.get();
      if (userMealsDoc.exists) {
        const userMealsData = userMealsDoc.data();
        waterData = userMealsData.Water || null;
        stepsData = userMealsData.Steps || null;
        console.log(`Found water data: ${waterData}, steps data: ${stepsData}`);
      }
    } catch (error) {
      console.log(`Error fetching water/steps data: ${error.message}`);
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

                  // Extract macro data from various possible sources
                  let protein = 0, carbs = 0, fat = 0;
                  if (item.macros && typeof item.macros === "object") {
                    protein = typeof item.macros.protein === "number" ? item.macros.protein : 0;
                    carbs = typeof item.macros.carbs === "number" ? item.macros.carbs : 0;
                    fat = typeof item.macros.fat === "number" ? item.macros.fat : 0;
                  } else if (item.nutrition && typeof item.nutrition === "object") {
                    protein = parseFloat(item.nutrition.protein) || 0;
                    carbs = parseFloat(item.nutrition.carbs) || 0;
                    fat = parseFloat(item.nutrition.fat) || 0;
                  } else if (item.nutritionalInfo && typeof item.nutritionalInfo === "object") {
                    protein = parseFloat(item.nutritionalInfo.protein) || 0;
                    carbs = parseFloat(item.nutritionalInfo.carbs) || 0;
                    fat = parseFloat(item.nutritionalInfo.fat) || 0;
                  }

                  // Debug logging for macro data
                  if (protein > 0 || carbs > 0 || fat > 0) {
                    console.log(`Found macro data for ${item.name}: Protein: ${protein}g, Carbs: ${carbs}g, Fat: ${fat}g`);
                  }

                  // Add to grand totals
                  totalCalories += calories;
                  totalProtein += protein;
                  totalCarbs += carbs;
                  totalFat += fat;

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
        water: waterData,
        steps: stepsData,
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
      console.log(`Macro totals - Protein: ${totalProtein}g, Carbs: ${totalCarbs}g, Fat: ${totalFat}g`);
      console.log(`Activity data - Water: ${waterData}, Steps: ${stepsData}`);
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
 * A Firestore-triggered Cloud Function that updates the daily summary
 * when water or steps data is modified in userMeals.
 * This ensures the daily summary stays in sync even when only activity data changes.
 */
exports.updateDailySummaryOnActivityChange = functions.firestore
  .document("userMeals/{userId}/meals/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    console.log(
      `--- Function updateDailySummaryOnActivityChange triggered for user: ${userId} on date: ${date} ---`
    );

    // Check if Water or Steps fields were modified
    const beforeData = change.before.exists ? change.before.data() : {};
    const afterData = change.after.exists ? change.after.data() : {};
    
    const waterChanged = beforeData.Water !== afterData.Water;
    const stepsChanged = beforeData.Steps !== afterData.Steps;
    
    // Only proceed if water or steps changed, and meals didn't change
    // (meals are handled by the calculateDailyNutrition function)
    if (!waterChanged && !stepsChanged) {
      console.log("No water or steps data changed, skipping update");
      return null;
    }
    
    // Check if meals data also changed - if so, let the calculateDailyNutrition function handle it
    const beforeMeals = beforeData.meals || {};
    const afterMeals = afterData.meals || {};
    const mealsChanged = JSON.stringify(beforeMeals) !== JSON.stringify(afterMeals);
    
    if (mealsChanged) {
      console.log("Meals data also changed, letting calculateDailyNutrition handle the update");
      return null;
    }

    console.log(`Water changed: ${waterChanged}, Steps changed: ${stepsChanged}`);

    try {
      // Get the current daily summary
      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);
      
      const summaryDoc = await summaryDocRef.get();
      
      if (!summaryDoc.exists) {
        console.log("No daily summary exists for this date, skipping update");
        return null;
      }

      const currentSummary = summaryDoc.data();
      
      // Update only the water and steps fields
      const updatedSummary = {
        ...currentSummary,
        water: afterData.Water || null,
        steps: afterData.Steps || null,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };

      await summaryDocRef.set(updatedSummary, { merge: true });

      console.log(
        `Successfully updated daily summary activity data for user ${userId} on ${date}`
      );
      console.log(`Updated water: ${afterData.Water}, steps: ${afterData.Steps}`);
      console.log("--- Function updateDailySummaryOnActivityChange finished ---");
      
      return null;
    } catch (error) {
      console.error(
        `Error updating daily summary activity data for user ${userId} on ${date}:`,
        error
      );
      console.error("--- Function updateDailySummaryOnActivityChange ERRORED ---");
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

        // Try to find existing ingredient with robust name checking
        ingredientId = await _findExistingIngredient(name);

        if (!ingredientId) {
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
 * Helper function to find existing ingredient with robust name checking
 * @param {string} ingredientName The name of the ingredient to find.
 * @returns {Promise<string|null>} The ingredient's document ID or null if not found.
 */
async function _findExistingIngredient(ingredientName) {
  try {
    const ingredientsRef = firestore.collection("ingredients");
    const normalizedName = _normalizeIngredientName(ingredientName);
    
    // 1. Try exact match first
    let snapshot = await ingredientsRef
      .where("title", "==", ingredientName.toLowerCase())
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      return snapshot.docs[0].id;
    }
    
    // 2. Try normalized name match
    snapshot = await ingredientsRef
      .where("title", "==", normalizedName)
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      return snapshot.docs[0].id;
    }
    
    // 3. Try normalized matching (remove spaces, hyphens, underscores)
    const normalizedInputName = _normalizeIngredientName(ingredientName);
    
    // Get all ingredients and check for normalized matches
    const allIngredientsSnapshot = await ingredientsRef.get();
    
    for (const doc of allIngredientsSnapshot.docs) {
      const ingredientData = doc.data();
      const dbTitle = ingredientData.title || '';
      const normalizedDbTitle = _normalizeIngredientName(dbTitle);
      
      if (normalizedInputName === normalizedDbTitle) {
        return doc.id;
      }
    }
    
    return null;
  } catch (error) {
    console.error(`Error finding existing ingredient "${ingredientName}":`, error);
    return null;
  }
}

/**
 * Normalize ingredient name by removing spaces, hyphens, and underscores
 * @param {string} ingredientName The ingredient name to normalize.
 * @returns {string} The normalized ingredient name.
 */
function _normalizeIngredientName(ingredientName) {
  // Remove spaces, hyphens, and underscores, convert to lowercase
  return ingredientName.toLowerCase().replace(/[\s\-_]/g, '');
}

/**
 * Helper function to generate details for an ingredient using Gemini and save it.
 * It uses .add() to create an auto-generated ID.
 * @param {string} ingredientName The name of the ingredient.
 * @returns {Promise<string|null>} The new ingredient's document ID or null.
 */
async function _generateAndSaveIngredient(ingredientName) {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const prompt = `
      Generate a detailed JSON object for the ingredient "${ingredientName}".
      The JSON object must match this structure:
      {
  "title": "${ingredientName}",
  "type": "ONLY USE THESE TYPES: protein, grain, vegetable, fruit, sweetener, condiment, pastry, dairy, oil, herb, spice, liquid", 
  "calories": number,
  "macros": {
    "protein": "string",
    "carbs": "string",
    "fat": "string"
  },
  "categories": ["string"],
  "features": {
    "fiber": "string",
    "g_i": "string",
    "season": "string",
    "water": "string",
    "rainbow": "string"
  },
  "techniques": [
    "string"
  ],
  "storageOptions": {
    "countertop": "string",
    "fridge": "string",
    "freezer": "string"
  },
  "isAntiInflammatory": boolean,
  "alt": ["string"],
  "image": "string"
}
      
      IMPORTANT: The "type" field MUST be one of these values ONLY:
      - "protein" (for meat, fish, eggs, tofu, etc.)
      - "grain" (for rice, pasta, bread, quinoa, etc.)
      - "vegetable" (for carrots, broccoli, spinach, etc.)
      - "fruit" (for apples, bananas, berries, etc.)
      - "sweetener" (for sugar, honey, maple syrup, etc.)
      - "condiment" (for ketchup, mustard, soy sauce, etc.)
      - "pastry" (for cakes, cookies, pies, etc.)
      - "dairy" (for milk, cheese, yogurt, etc.)
      - "oil" (for olive oil, coconut oil, etc.)
      - "herb" (for basil, thyme, rosemary, etc.)
      - "spice" (for salt, pepper, cinnamon, etc.)
      - "liquid" (for water, broth, juice, etc.)
      
      Do not use any other type values. Choose the most appropriate one from the list above.
      Do not include any text, markdown, or formatting outside of the JSON object itself.
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text().replace(/```json|```/g, "").trim();
    const ingredientData = JSON.parse(text);

    // Validate and ensure the type is one of the allowed values
    const allowedTypes = ['protein', 'grain', 'vegetable', 'fruit', 'sweetener', 'condiment', 'pastry', 'dairy', 'oil', 'herb', 'spice', 'liquid'];
    if (!allowedTypes.includes(ingredientData.type)) {
      console.warn(`Invalid type "${ingredientData.type}" for ingredient "${ingredientName}". Defaulting to "vegetable".`);
      ingredientData.type = 'vegetable'; // Default fallback
    }

    ingredientData.createdAt = admin.firestore.FieldValue.serverTimestamp();

    const newIngredientRef = await firestore.collection("ingredients").add(ingredientData);
    
    console.log(`Successfully generated and saved new ingredient: ${ingredientData.title} (ID: ${newIngredientRef.id}) with type: ${ingredientData.type}`);
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

// Post-related cloud functions for optimized feed loading

// Efficient post loading with server-side filtering and pagination
exports.getPostsFeed = functions.https.onCall(async (data, context) => {
  try {
    const {
      category = 'general',
      limit = 24,
      lastPostId = null,
      excludePostId = null,
      includeBattlePosts = true
    } = data;

    // Build query with server-side filtering
    let query = admin.firestore()
      .collection('posts')
      .orderBy('createdAt', 'desc'); // Simple query - no compound index needed

    // Apply category filtering on server
    if (category && category.toLowerCase() !== 'all' && category.toLowerCase() !== 'general') {
      query = query.where('category', '==', category);
    }

    // Apply pagination
    if (lastPostId) {
      const lastDoc = await admin.firestore().collection('posts').doc(lastPostId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    query = query.limit(limit);

    const snapshot = await query.get();
    
    const posts = [];
    const batchPromises = [];

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      // Skip excluded post
      if (excludePostId && doc.id === excludePostId) {
        return;
      }

      // Skip private posts (client-side filtering)
      if (data.battleId === 'private') {
        return;
      }

      // Only include essential data for grid view (optimization)
      const optimizedPost = {
        id: doc.id,
        mealId: data.mealId || '', // Add mealId for proper meal-post association
        mediaPaths: data.mediaPaths || [],
        isVideo: data.isVideo || false,
        category: data.category || 'general',
        name: data.name || 'Unknown',
        userId: data.userId || '',
        createdAt: data.createdAt,
        isBattle: data.isBattle || false,
        // Don't include heavy fields like full content, comments, etc.
      };

      posts.push(optimizedPost);

      // Batch user data fetching for efficiency
      if (data.userId) {
        batchPromises.push(
          admin.firestore().collection('users').doc(data.userId).get()
        );
      }
    });

    // Fetch user data in batch
    const userDocs = await Promise.all(batchPromises);
    const userMap = {};
    
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const userData = userDoc.data();
        userMap[userDoc.id] = {
          displayName: userData.displayName || 'Anonymous',
          avatar: userData.avatar || '',
          isPremium: userData.isPremium || false
        };
      }
    });

    // Attach user data to posts
    posts.forEach(post => {
      if (post.userId && userMap[post.userId]) {
        post.userName = userMap[post.userId].displayName;
        post.userAvatar = userMap[post.userId].avatar;
        post.userIsPremium = userMap[post.userId].isPremium;
      }
    });

    return {
      success: true,
      posts: posts,
      hasMore: snapshot.docs.length === limit,
      lastPostId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null,
      totalFetched: snapshot.docs.length
    };

  } catch (error) {
    console.error('Error fetching posts:', error);
    return {
      success: false,
      error: error.message,
      posts: []
    };
  }
});

// Get user-specific posts with optimized server-side processing
exports.getUserPosts = functions.https.onCall(async (data, context) => {
  try {
    const {
      userId,
      limit = 30,
      lastPostId = null,
      includeUserData = true
    } = data;

    if (!userId) {
      return {
        success: false,
        error: 'userId is required',
        posts: []
      };
    }

    // Build query to fetch user's posts directly from posts collection
    let query = admin.firestore()
      .collection('posts')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc');

    // Apply pagination
    if (lastPostId) {
      const lastDoc = await admin.firestore().collection('posts').doc(lastPostId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    query = query.limit(limit);

    const snapshot = await query.get();
    const posts = [];

    // Get user data once if needed
    let userData = null;
    if (includeUserData) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userDataRaw = userDoc.data();
        userData = {
          displayName: userDataRaw.displayName || 'Anonymous',
          profileImage: userDataRaw.profileImage || '',
          isPremium: userDataRaw.isPremium || false
        };
      }
    }

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      const optimizedPost = {
        id: doc.id,
        mealId: data.mealId || '', // Add mealId for proper meal-post association
        userId: data.userId || '',
        mediaPaths: data.mediaPaths || [],
        isVideo: data.isVideo || false,
        category: data.category || 'general',
        name: data.name || 'Unknown',
        createdAt: data.createdAt,
        isBattle: data.isBattle || false,
        battleId: data.battleId || '',
        favorites: data.favorites || [],
      };

      // Attach user data if available
      if (userData) {
        optimizedPost.userName = userData.displayName;
        optimizedPost.userAvatar = userData.profileImage;
        optimizedPost.userIsPremium = userData.isPremium;
      }

      posts.push(optimizedPost);
    });

    return {
      success: true,
      posts: posts,
      hasMore: snapshot.docs.length === limit,
      lastPostId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null,
      totalFetched: snapshot.docs.length,
      userData: userData
    };

  } catch (error) {
    console.error('Error fetching user posts:', error);
    return {
      success: false,
      error: error.message,
      posts: []
    };
  }
});

// Get battle posts for the current week (Monday to Friday)
exports.getChallengePostsForWeek = functions.https.onCall(async (data, context) => {
  try {
    const {
      weekStart,
      weekEnd,
      limit = 20
    } = data;

    if (!weekStart || !weekEnd) {
      return {
        success: false,
        error: 'weekStart and weekEnd are required',
        posts: []
      };
    }

    // Convert ISO strings to Firestore timestamps
    const startDate = new Date(weekStart);
    const endDate = new Date(weekEnd);
    
    console.log('Date range for battle posts:', {
      weekStart,
      weekEnd,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString()
    });

    // Build query to fetch all battle posts (we'll filter by date on server side)
    let query = admin.firestore()
      .collection('posts')
      .where('isBattle', '==', true)
      .orderBy('createdAt', 'desc')
      .limit(limit * 2); // Get more posts to account for date filtering

    const snapshot = await query.get();
    console.log(`Found ${snapshot.docs.length} battle posts total`);
    
    const posts = [];
    const batchPromises = [];

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      // Skip private posts
      if (data.battleId === 'private') {
        return;
      }

      // Filter by date range on server side since createdAt is a string
      if (data.createdAt) {
        const postDate = new Date(data.createdAt);
        console.log('Checking post date:', {
          postId: doc.id,
          createdAt: data.createdAt,
          postDate: postDate.toISOString(),
          isInRange: postDate >= startDate && postDate <= endDate
        });
        if (postDate < startDate || postDate > endDate) {
          return; // Skip posts outside the date range
        }
      }

      // Only include essential data for horizontal list view
      const optimizedPost = {
        id: doc.id,
        mealId: data.mealId || '',
        mediaPaths: data.mediaPaths || [],
        isVideo: data.isVideo || false,
        category: data.category || 'general',
        name: data.name || 'Unknown',
        username: data.name || 'Unknown', // For display in horizontal list
        userId: data.userId || '',
        createdAt: data.createdAt,
        isBattle: data.isBattle || false,
        battleId: data.battleId || '',
        favorites: data.favorites || [],
      };

      posts.push(optimizedPost);

      // Batch user data fetching for efficiency
      if (data.userId) {
        batchPromises.push(
          admin.firestore().collection('users').doc(data.userId).get()
        );
      }
    });

    // Fetch user data in batch
    const userDocs = await Promise.all(batchPromises);
    const userMap = {};
    
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const userData = userDoc.data();
        userMap[userDoc.id] = {
          displayName: userData.displayName || 'Anonymous',
          avatar: userData.avatar || '',
          isPremium: userData.isPremium || false
        };
      }
    });

    // Attach user data to posts
    posts.forEach(post => {
      if (post.userId && userMap[post.userId]) {
        post.username = userMap[post.userId].displayName;
        post.avatar = userMap[post.userId].avatar;
        post.isPremium = userMap[post.userId].isPremium;
      }
    });

    return {
      success: true,
      posts: posts,
      totalFetched: posts.length
    };

  } catch (error) {
    console.error('Error fetching battle posts:', error);
    return {
      success: false,
      error: error.message,
      posts: []
    };
  }
});

/**
 * Firebase Function to process pending meals with AI-generated details
 * Uses exponential backoff retry logic with jitter for reliability
 */
exports.processPendingMeals = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    try {
      console.log('--- Starting meal processing job ---');
      
      // Get all meals that need processing
      const pendingMealsQuery = admin.firestore()
        .collection('meals')
        .where('needsProcessing', '==', true)
        .where('status', '==', 'pending')
        .orderBy('processingPriority', 'asc')
        .limit(10); // Process 10 meals at a time to avoid timeouts
      
      const pendingMealsSnapshot = await pendingMealsQuery.get();
      
      if (pendingMealsSnapshot.empty) {
        console.log('No pending meals to process');
        return null;
      }
      
      console.log(`Found ${pendingMealsSnapshot.docs.length} pending meals to process`);
      
      const processingPromises = pendingMealsSnapshot.docs.map(async (doc) => {
        const mealData = doc.data();
        const mealId = doc.id;
        
        try {
          // Mark as processing to prevent duplicate processing
          await doc.ref.update({
            status: 'processing',
            lastProcessingAttempt: admin.firestore.FieldValue.serverTimestamp(),
            processingAttempts: admin.firestore.FieldValue.increment(1)
          });
          
          console.log(`Processing meal: ${mealData.title} (ID: ${mealId})`);
          
          // Generate full meal details using AI
          const fullMealDetails = await generateFullMealDetails(
            mealData.title,
            mealData.ingredients || {},
            mealData.mealType || 'general'
          );
          
          // Update meal with complete details
          await doc.ref.update({
            ...fullMealDetails,
            status: 'completed',
            needsProcessing: false,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            version: 'complete'
          });
          
          console.log(`Successfully completed meal: ${mealData.title}`);
          
        } catch (error) {
          console.error(`Error processing meal ${mealData.title}:`, error);
          
          // Implement exponential backoff with jitter
          const attempts = (mealData.processingAttempts || 0) + 1;
          const maxAttempts = 5;
          
          // Calculate backoff delay with jitter
          const baseDelay = Math.pow(2, attempts) * 1000; // Base delay in ms
          const jitter = Math.random() * 1000; // Random jitter up to 1 second
          const totalDelay = baseDelay + jitter;
          
          // Schedule retry by updating priority (lower priority = processed later)
          const retryTime = Date.now() + totalDelay;
          await doc.ref.update({
            status: 'pending',
            needsProcessing: true,
            processingPriority: retryTime,
            lastError: error.message,
            processingAttempts: attempts
          });
          
          console.log(`Scheduled retry for meal ${mealData.title} in ${Math.round(totalDelay/1000)}s (attempt ${attempts})`);
          
          // Only mark as failed after max attempts
          if (attempts >= maxAttempts) {
            await doc.ref.update({
              status: 'failed',
              needsProcessing: false,
              failedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`Marked meal ${mealData.title} as failed after ${attempts} attempts`);
          }
        }
      });
      
      // Wait for all meals to be processed
      await Promise.all(processingPromises);
      
      console.log('--- Meal processing job completed ---');
      return null;
      
    } catch (error) {
      console.error('Error in meal processing job:', error);
      return null;
    }
  });

/**
 * Helper function to generate full meal details using AI
 */
async function generateFullMealDetails(title, basicIngredients, mealType) {
  try {
    // Use Gemini API to generate complete meal details
    const prompt = `Generate complete meal details for: ${title}
    
    Basic ingredients: ${JSON.stringify(basicIngredients)}
    Meal type: ${mealType}
    
    Please provide:
    1. Complete ingredient list with measurements
    2. Step-by-step cooking instructions
    3. Nutritional information (calories, protein, carbs, fat)
    4. Cooking time and difficulty
    5. Serving size
    6. Dietary categories (vegan, gluten-free, etc.)
    7. Cuisine type
    
    Format as JSON with these fields:
    {
      "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
      },
      "instructions": ["step1", "step2", ...],
      "calories": number,
      "nutritionalInfo": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number
      },
      "cookingTime": "X minutes",
      "difficulty": "easy/medium/hard",
      "serveQty": number,
      "categories": ["category1", "category2"],
      "cuisine": "cuisine type"
      "type": "protein|grain|vegetable"
    }`;
    
    const result = await genAI.getGenerativeModel({ model: "gemini-1.5-flash" })
      .generateContent(prompt);
    
    const response = result.response.text();
    
    // Parse JSON response
    try {
      const mealDetails = JSON.parse(response);
      
      // Validate that we have the essential fields
      if (!mealDetails.ingredients || !mealDetails.instructions || !mealDetails.nutritionalInfo) {
        throw new Error('Missing essential meal fields in AI response');
      }
      
      // Return validated meal data
      return {
        ingredients: mealDetails.ingredients,
        instructions: mealDetails.instructions,
        calories: mealDetails.calories || 300,
        nutritionalInfo: mealDetails.nutritionalInfo,
        cookingTime: mealDetails.cookingTime || '30 minutes',
        difficulty: mealDetails.difficulty || 'medium',
        serveQty: mealDetails.serveQty || 1,
        type: mealDetails.type || 'protein',
        categories: mealDetails.categories || [mealType],
        cuisine: mealDetails.cuisine || 'general',
        aiGenerated: true,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      };
      
    } catch (parseError) {
      console.error('Error parsing AI response:', parseError);
      // Don't return fallback data - let the retry logic handle this
      throw new Error(`Failed to parse AI response: ${parseError.message}`);
    }
    
  } catch (error) {
    console.error('Error generating meal details:', error);
    // Don't return fallback data - let the retry logic handle this
    throw error;
  }
}

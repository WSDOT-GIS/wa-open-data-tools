import assert from "node:assert/strict";
import { query, attributeNames, dateFieldRegex } from "./index.js";

// function test() {
//   // Test copied from Postman.
//   const response = pm.response.json(function (key, value) {
//     if (dateFieldRe.test(key) && typeof value === "number") {
//       return new Date(value);
//     }
//     return value;
//   });

//   // pm.test("Response is in expected format", function () {

const response = await query();
const collectionPropertyNames = ["features", "fields"];

for (const propertyName of collectionPropertyNames) {
  assert.notStrictEqual(response, null);
  assert.strictEqual(Object.hasOwn(response, propertyName), true);
  const collection: Array<unknown> = (response as never)[propertyName];
  assert.notEqual(collection, null);
  assert.strictEqual(
    Array.isArray(collection) && collection.length > 0,
    true,
    `Collection "${propertyName}" should have at least one element.`
  );
}

for (const feature of response.features) {
  assert.strictEqual(Object.hasOwn(feature, "attributes"), true);
  for (const attributeName in feature.attributes) {
    const value = feature.attributes[attributeName];
    assert.ok(attributeNames.includes(attributeName));
    if (dateFieldRegex.test(attributeName)) {
      assert.ok(value instanceof Date);
    }
  }
}
//   // });
// }

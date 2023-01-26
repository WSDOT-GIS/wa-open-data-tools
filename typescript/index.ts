import type { FeatureSet } from "arcgis-rest-api";
export const dateFieldRegex = /date/gi;

function reviver(key: string, value: unknown) {
  if (dateFieldRegex.test(key) && typeof value === "number") {
    return new Date(value);
  }
  if (typeof value === "string" && /^\s*$/.test(value)) {
    return null;
  }
  return value;
}

const defaultParams = {
  where: "questions_contact LIKE '@wsdot.wa.gov'",
  outFields: "*",
  returnGeometry: false,
  sqlFormat: "none",
  f: "json",
};

const defaultUrl =
  "https://services.arcgis.com/jsIt88o09Q0r1j8h/ArcGIS/rest/services/survey123_75f94f8a0675460796843c95665a814b/FeatureServer/0/query";

/**
 * Expected attributes that should be present in each `feature.attributes` object.
 */
export const attributeNames = [
  "ObjectId",
  "globalid",
  "CreationDate",
  "Creator",
  "EditDate",
  "Editor",
  "name_of_content_impacted",
  "brief_summary",
  "reason_for_change",
  "date_of_change",
  "level_of_impact",
  "impact_informational",
  "impact_informational_other",
  "impact_critical",
  "impact_critical_other",
  "additional_information",
  "informational_url",
  "additional_informational_url",
  "questions_contact",
  "type_of_notification",
];

export type QueryOutputValue =
  | string
  | number
  | boolean
  | Date
  | null
  | QueryOutputValue[];

export type QueryOutput = Record<
  string,
  QueryOutputValue | Record<string, QueryOutputValue>
>;

export async function query(
  url = defaultUrl,
  params: Record<string, unknown> = defaultParams
) {
  const requestUrl = new URL(url);
  for (const key in params) {
    if (Object.hasOwn(params, key)) {
      const value = params[key];
      if (value == null) {
        continue;
      }
      requestUrl.searchParams.set(key, value as string);
    }
  }
  const response = await fetch(requestUrl);
  const json = await response.text();

  const result = JSON.parse(json, reviver);
  if (Object.hasOwn(result, "error")) {
    throw new TypeError(result["error"]);
  }

  return result as FeatureSet;
}

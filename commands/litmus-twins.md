---
description: Overview of Digital Twin models and instances on the Litmus Edge.
---

Optional model or instance name: `$ARGUMENTS`

1. Call `list_digital_twin_models`.
2. Call `list_digital_twin_instances` with no `model_id` to get every instance at once.
3. Call `list_dynamic_attributes` with `all_instances=true`, then `list_static_attributes` with `all_instances=true`.

   Both accept exactly **one** of `model_id`, `instance_id`, `instance_name`, or `all_instances`. Use `all_instances=true` for this overview: it returns attributes grouped per instance in a single call. Querying just the first instance and presenting it as the whole picture is the failure mode these tools warn about.

If `$ARGUMENTS` names a specific model, also call `list_transformations` and `get_digital_twin_hierarchy` for that `model_id` to show its structure and processing rules.

Output:

- **Models** - table: Name, ID, Description, Instance count.
- **Instances** - table: Name, Model, Topic, Interval, Dynamic attrs, Static attrs.

Field names are capitalised, verified against a live Edge. Models return `ID`, `Name`, `Description`, `Assets` (the model type, e.g. `ASSET`). Instances return `ID`, `ModelID`, `Name`, `Topic`, `Interval`, `FlatHierarchy`.

Neither call gives you an instance count per model: derive it by grouping instances on `ModelID` and joining to the model `ID`. Resolve the Model column the same way, since instances carry only `ModelID`, not the model name.

Expect leftover test artifacts on shared or sandbox Edges. A live Edge returned models named like `unitTestDynamicAttributes1785286950` alongside real ones. Do not present those as production assets; group them under a short "test or scratch models" line with a count.
- **Structure** (only when a model was named) - the hierarchy as an indented tree, plus a table of transformations.

Vocabulary that matters here: a *model* is the schema, an *instance* is a running representation of it that publishes to a NATS topic. Static attributes are fixed key-value pairs like serial number or location; dynamic attributes are live data points like temperature or speed.

If there are no models, say so and note that instances cannot exist without one.

To read what an instance is actually publishing, take its topic and use `/litmus-topics` to confirm the subject, then `get_current_value_from_topic`.

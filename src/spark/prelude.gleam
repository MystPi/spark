import filepath
import spark/file

pub const filename = "spark.prelude.mjs"

pub const contents = "/* This is the Spark prelude. It is included in all projects when they are built.
The prelude can be accessed from external embedded code via `$`, enabling you to
interface with Spark's runtime data types and functions in helpful ways! */

export class Atom {
  constructor(name, payload) {
    this.name = name;
    this.payload = payload ?? [];
  }

  static hasRecordPayload(atom) {
    return atom instanceof Atom && atom.payload[0] instanceof Record;
  }
}

export function ok(payload) {
  return new Atom('ok', payload);
}

export function error(payload) {
  return new Atom('error', payload);
}

export const nil = new Atom('nil', []);
export const true_ = new Atom('true', []);
export const false_ = new Atom('false', []);

export class Record extends Map {
  static assertRecord(record, msg) {
    if (!(record instanceof Record)) throw new Error(msg);
  }

  static update(record, fields) {
    if (Atom.hasRecordPayload(record)) {
      record = record.payload[0];
    }

    Record.assertRecord(record, 'Cannot update a non-record');

    return new Record([...record, ...fields]);
  }

  static access(record, field) {
    // An atom can be accessed if the first value in its payload is a record.
    if (Atom.hasRecordPayload(record)) {
      record = record.payload[0];
    }

    Record.assertRecord(
      record,
      'Record has no `' + field + '` field because it is not a record'
    );

    if (record.has(field)) {
      return record.get(field);
    }

    throw new Error('Record has no `' + field + '` field');
  }
}

export function eq(a, b) {
  if (a == b) return true;
  else if (a instanceof Atom && b instanceof Atom) {
    if (a.name === b.name) {
      return eq(a.payload, b.payload);
    }
  } else if (a instanceof Record && b instanceof Record) {
    if (a.size === b.size) {
      return [...a].every(([key, value]) => eq(value, b.get(key)));
    }
  } else if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length === b.length) {
      return a.every((value, index) => eq(value, b[index]));
    }
  }

  return false;
}

export function checkArgs(name, args, expected, matchesPattern) {
  if (args.length !== expected) {
    throw new Error(
      `\\`${name}\\` expects ${expected} argument(s), got ${args.length}`
    );
  }

  if (matchesPattern !== undefined && !matchesPattern()) {
    throw new Error(`Argument(s) given to \\`${name}\\` didn't match pattern`);
  }
}
"

/// Create a copy of the prelude JavaScript module to the given build directory.
///
pub fn create(in build_dir: String) -> Result(Nil, String) {
  let path = filepath.join(build_dir, filename)

  file.write_all(path, contents)
}

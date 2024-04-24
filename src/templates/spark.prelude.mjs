export class Atom {
  constructor(name, payload) {
    this.name = name;
    this.payload = payload ?? [];
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

  static updateRecord(record, fields) {
    Record.assertRecord(record, 'Cannot update a non-record');
    return new Record([...record, ...fields]);
  }

  static access(record, field) {
    // An atom can be accessed if the first value in its payload is a record.
    if (record instanceof Atom && record.payload[0] instanceof Record) {
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

export function checkArgs(args, expected) {
  if (args.length !== expected) {
    throw new Error(
      'Expected ' + expected + ' argument(s), got ' + arguments.length
    );
  }
}
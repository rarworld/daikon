package daikon.inv.unary.sequence;

import daikon.*;
import daikon.inv.*;
import daikon.derive.unary.*;
import daikon.inv.unary.scalar.*;
import daikon.inv.unary.sequence.*;
import daikon.inv.binary.sequenceScalar.*;

import utilMDE.*;

import java.util.*;
import java.io.*;

// *****
// Do not edit this file directly:
// it is automatically generated from OneOf.java.jpp
// *****

// States that the value is one of the specified values.

// This subsumes an "exact" invariant that says the value is always exactly
// a specific value.  Do I want to make that a separate invariant
// nonetheless?  Probably not, as this will simplify implication and such.

public final class OneOfSequence  extends SingleSequence  implements OneOf {
  final static int LIMIT = 3 ;	// maximum size for the one_of list
  // Probably needs to keep its own list of the values, and number of each seen.
  // (That depends on the slice; maybe not until the slice is cleared out.
  // But so few values is cheap, so this is quite fine for now and long-term.)

  private long[] [] elts;
  private int num_elts;

  private boolean is_boolean;
  private boolean is_hashcode;

  OneOfSequence (PptSlice ppt) {
    super(ppt);

    elts = new long[LIMIT][];    // elements are interned, so can test with ==
                                // (in the general online case, not worth interning)

    num_elts = 0;

    Assert.assert(var().type.isPseudoArray(),
		  "ProglangType must be pseudo-array for EltOneOf or OneOfSequence");
    is_boolean = (var().type.elementType() == ProglangType.BOOLEAN);
    is_hashcode = var().type.elementType().isObject() || var().type.elementType().isArray();

  }

  public static OneOfSequence  instantiate(PptSlice ppt) {
    return new OneOfSequence (ppt);
  }

  public int num_elts() {
    return num_elts;
  }

  public Object elt() {
    if (num_elts != 1)
      throw new Error("Represents " + num_elts + " elements");

    return elts[0];

  }

  static Comparator comparator = new ArraysMDE.LongArrayComparatorLexical();

  private void sort_rep() {
    Arrays.sort(elts, 0, num_elts , comparator );
  }

  // Assumes the other array is already sorted
  public boolean compare_rep(int num_other_elts, long[] [] other_elts) {
    if (num_elts != num_other_elts)
      return false;
    sort_rep();
    for (int i=0; i < num_elts; i++)
      if (elts[i] != other_elts[i]) // elements are interned
        return false;
    return true;
  }

  private String subarray_rep() {
    // Not so efficient an implementation, but simple;
    // and how often will we need to print this anyway?
    sort_rep();
    StringBuffer sb = new StringBuffer();
    sb.append("{ ");
    for (int i=0; i<num_elts; i++) {
      if (i != 0)
        sb.append(", ");
      sb.append(ArraysMDE.toString( elts[i] ) );
    }
    sb.append(" }");
    return sb.toString();
  }

  public String repr() {
    return "OneOfSequence"  + varNames() + ": "
      + "no_invariant=" + no_invariant
      + ", num_elts=" + num_elts
      + ", elts=" + subarray_rep();
  }

  public String format() {
    String varname = var().name.name() ;
    if (num_elts == 1) {

      if (is_hashcode) {
        if (elts[0].length == 0) {
          return varname + " == []";
        } else if ((elts[0].length == 1) && (elts[0][0] == 0)) {
          return varname + " == [null]";
        } else {
          return varname + " has only one value, of length " + elts[0].length;
        }
      } else {
        return varname + " == " + ArraysMDE.toString( elts[0] ) ;
      }

    } else {
      return varname + " one of " + subarray_rep();
    }
  }

  public String format_esc() {

    String result;

    result = "format_esc " + this.getClass() + " needs to be changed: " + format();

    return result;
  }

  public String format_simplify() {

    String result;

    result =  "format_simplify " + this.getClass() + " needs to be changed: " + format();

    return result;
  }

  public void add_modified(long[]  v, int count) {

    Assert.assert(Intern.isInterned(v));

    for (int i=0; i<num_elts; i++)
      if (elts[i] == v) {

        return;

      }
    if (num_elts == LIMIT) {
      destroy();
      return;
    }

    if (is_hashcode && (num_elts == 1)) {
      destroy();
      return;
    }

    elts[num_elts] = v;
    num_elts++;

  }

  protected double computeProbability() {
    // This is not ideal.
    if (num_elts == 0) {
      return Invariant.PROBABILITY_UNKNOWN;

    } else {
      return Invariant.PROBABILITY_JUSTIFIED;
    }
  }

  public boolean isSameFormula(Invariant o)
  {
    OneOfSequence  other = (OneOfSequence ) o;
    if (num_elts != other.num_elts)
      return false;

    sort_rep();
    other.sort_rep();
    for (int i=0; i < num_elts; i++)
      if (elts[i] != other.elts[i]) // elements are interned
	return false;

    return true;
  }

  public boolean isExclusiveFormula(Invariant o)
  {
    if (o instanceof OneOfSequence ) {
      OneOfSequence  other = (OneOfSequence ) o;

      for (int i=0; i < num_elts; i++) {
        for (int j=0; j < other.num_elts; j++) {
          if (elts[i] == other.elts[j]) // elements are interned
            return false;
        }
      }
      return true;
    }

    return false;
  }

  // OneOf invariants that indicate a small set of possible values are
  // uninteresting.  OneOf invariants that indicate exactly one value
  // are interesting.
  public boolean isInteresting() {
    if (num_elts() > 1) {
      return false;
    } else {
      return true;
    }
  }

  // Look up a previously instantiated invariant.
  public static OneOfSequence  find(PptSlice ppt) {
    Assert.assert(ppt.arity == 1);
    for (Iterator itor = ppt.invs.iterator(); itor.hasNext(); ) {
      Invariant inv = (Invariant) itor.next();
      if (inv instanceof OneOfSequence )
        return (OneOfSequence ) inv;
    }
    return null;
  }

  // Interning is lost when an object is serialized and deserialized.
  // Manually re-intern any interned fields upon deserialization.
  private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
    in.defaultReadObject();
    for (int i=0; i < num_elts; i++)
      elts[i] = Intern.intern(elts[i]);
  }

}


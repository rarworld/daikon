package daikon.inv.unary;

import daikon.PptSlice;
import daikon.inv.Invariant;
import utilMDE.Assert;

/**
 * Exists simply to provide the do-nothing resusurrect_done method.
 **/
public abstract class UnaryInvariant
  extends Invariant
{
  // We are Serializable, so we specify a version to allow changes to
  // method signatures without breaking serialization.  If you add or
  // remove fields, you should change this number to the current date.
  static final long serialVersionUID = 20020122L;

  /** Pass-through */
  protected UnaryInvariant(PptSlice ppt) {
    super(ppt);
  }

  /** @return this */
  protected Invariant resurrect_done(int[] permutation) {
    Assert.assert(permutation.length == 1);
    Assert.assert(permutation[0] == 0);
    return this;
  }

}

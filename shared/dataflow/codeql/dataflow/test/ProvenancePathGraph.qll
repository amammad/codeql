/**
 * Provides a module for renumbering MaD IDs in data flow path explanations in
 * order to produce more stable test output.
 *
 * In addition to the `PathGraph`, a `query predicate models` is provided to
 * list the contents of the referenced MaD rows.
 */
module;

signature predicate interpretModelForTestSig(QlBuiltins::ExtensionId madId, string model);

signature predicate queryResultsSig(string relation, int row, int column, string data);

signature class PathNodeSig {
  string toString();
}

signature module PathGraphSig<PathNodeSig PathNode> {
  /** Holds if `(a,b)` is an edge in the graph of data flow path explanations. */
  predicate edges(PathNode a, PathNode b, string key, string val);

  /** Holds if `n` is a node in the graph of data flow path explanations. */
  predicate nodes(PathNode n, string key, string val);

  /**
   * Holds if `(arg, par, ret, out)` forms a subpath-tuple, that is, flow through
   * a subpath between `par` and `ret` with the connecting edges `arg -> par` and
   * `ret -> out` is summarized as the edge `arg -> out`.
   */
  predicate subpaths(PathNode arg, PathNode par, PathNode ret, PathNode out);
}

private signature predicate provenanceSig(string model);

private module TranslateModels<
  interpretModelForTestSig/2 interpretModelForTest, provenanceSig/1 provenance>
{
  private predicate madIds(string madId) {
    exists(string model |
      provenance(model) and
      model.regexpFind("(?<=MaD:)[0-9]*", _, _) = madId
    )
  }

  private predicate rankedMadIds(string madId, int r) {
    madId = rank[r](string madId0 | madIds(madId0) | madId0 order by madId0.toInt())
  }

  /** Lists the renumbered and pretty-printed models used in the edges relation. */
  predicate models(int r, string model) {
    exists(QlBuiltins::ExtensionId madId |
      rankedMadIds(madId.toString(), r) and interpretModelForTest(madId, model)
    )
  }

  private predicate translateModelsPart(string model1, string model2, int i) {
    provenance(model1) and
    exists(string s | model1.splitAt("MaD:", i) = s |
      model2 = s and i = 0
      or
      exists(string part, string madId, string rest, int r |
        translateModelsPart(model1, part, i - 1) and
        madId = s.regexpCapture("([0-9]*)(.*)", 1) and
        rest = s.regexpCapture("([0-9]*)(.*)", 2) and
        rankedMadIds(madId, r) and
        model2 = part + "MaD:" + r + rest
      )
    )
  }

  predicate translateModels(string model1, string model2) {
    exists(int i |
      translateModelsPart(model1, model2, i) and
      not translateModelsPart(model1, _, i + 1)
    )
  }
}

/** Transforms a `PathGraph` by printing the provenance information. */
module ShowProvenance<
  interpretModelForTestSig/2 interpretModelForTest, PathNodeSig PathNode,
  PathGraphSig<PathNode> PathGraph>
{
  private predicate provenance(string model) { PathGraph::edges(_, _, _, model) }

  private module Models = TranslateModels<interpretModelForTest/2, provenance/1>;

  query predicate models(int r, string model) { Models::models(r, model) }

  query predicate edges(PathNode a, PathNode b, string key, string val) {
    exists(string model |
      PathGraph::edges(a, b, key, model) and
      Models::translateModels(model, val)
    )
  }

  query predicate nodes = PathGraph::nodes/3;

  query predicate subpaths = PathGraph::subpaths/4;
}

/** Transforms a `PathGraph` by printing the provenance information. */
module TranslateProvenanceResults<
  interpretModelForTestSig/2 interpretModelForTest, queryResultsSig/4 queryResults>
{
  private int provenanceColumn() { result = 5 }

  private predicate provenance(string model) { queryResults("edges", _, provenanceColumn(), model) }

  private module Models = TranslateModels<interpretModelForTest/2, provenance/1>;

  predicate results(string relation, int row, int column, string data) {
    queryResults(relation, row, column, data) and
    (relation != "edges" or column != provenanceColumn())
    or
    exists(string model |
      relation = "edges" and
      column = provenanceColumn() and
      queryResults(relation, row, column, model) and
      Models::translateModels(model, data)
    )
    or
    exists(int r, string model |
      Models::models(r, model) and
      relation = "models" and
      row = r
    |
      column = 0 and data = r.toString()
      or
      column = 1 and data = model
    )
  }
}

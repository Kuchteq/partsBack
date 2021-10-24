const withParams = (string, page, sort_by, sort_dir = 'ASC', sQuery, dbprefixes) => {
  /**
   * @param string [Required]
   * @param page [Required]
   * @param sort_by [Required]
   */
  if (Number.isNaN(parseInt(page, 10))) {
    return '';
  }
  const intPage = parseInt(page, 10);
  const limit = 20;
  const startIndex = (intPage - 1) * limit;
  let constructedQuery = '';

  if (sQuery) {
    sQuery = sQuery.replace(' ', '+');
    constructedQuery = 'WHERE ';
    dbprefixes.forEach((prefix, i) => {
      constructedQuery += `${prefix}.document_with_weights @@ to_tsquery('"${sQuery}":*')`;
      if (i < dbprefixes.length - 1) constructedQuery += ' OR ';
    });
    sort_by = `ts_rank(${dbprefixes[0]}.document_with_weights, to_tsquery('"${sQuery}":*'))`;
  }

  return `${string} ${constructedQuery} ORDER BY ${sort_by} ${sort_dir} OFFSET ${startIndex} LIMIT ${limit}`;
};

module.exports = withParams;

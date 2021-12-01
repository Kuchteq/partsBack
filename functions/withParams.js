const withParams = (string, page, sort_by, sort_dir = 'ASC', sQuery, dbprefixes) => {
  /* Function used to modify query by adding the functionality
  of sorting the data and filtering it based on the search parameter - sQuery
   */
  if (Number.isNaN(parseInt(page, 10))) {
    return '';
  }

  // Parse string "page" to decimal int
  const intPage = parseInt(page, 10);

  /*The default limit set to be returned by the query, modifying it would make
  whilst browsing through some module such as inventory, the user fetches more data less often 
  if it is set to a higher number and if it's low, the user has to make more queries but the
  data returned to him is smaller*/
  const limit = 20;

  //If the requested page is not the first one, start from the higher position
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

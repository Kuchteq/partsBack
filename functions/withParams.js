const withParams = (string, page, sort_by, sort_dir = 'ASC', sQuery, dbprefixes, conditions) => {
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

  //If the client has requested to filter the data by a specific search parameter

  return `${onlySearch(string, sQuery, dbprefixes, conditions)} ORDER BY ${sort_by} ${sort_dir} OFFSET ${startIndex} LIMIT ${limit}`;
};

const onlySearch = (string, sQuery, dbprefixes, conditions = "", prefix = 'WHERE ', suffix = '') => {
  /* Function used to modify query by adding the functionality
  of filtering the data based on the search parameter - sQuery
   */
  let constructedQuery = ''
  if (conditions && sQuery) {
    constructedQuery = prefix + conditions + " AND (";
  }
  else if (conditions && !sQuery) {
    constructedQuery = prefix + "(" + conditions + ")";
  }
  else if (!conditions && sQuery) {
    constructedQuery = prefix + "(";
  }
  if (sQuery) {
    sQuery = sQuery.replace(' ', '+');
    dbprefixes.forEach((prefix, i) => {
      constructedQuery += `${prefix}.document_with_weights @@ to_tsquery('"${sQuery}":*')`;
      if (i < dbprefixes.length - 1) { constructedQuery += ' OR ' } else constructedQuery += ' ) ';
    });
  }

  return `${string} ${constructedQuery} ${suffix}`;
}
module.exports = { withParams, onlySearch };

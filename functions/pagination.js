const withPaginSort = (string, page, sort_by, sort_dir = 'ASC') => {
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
  if (sort_by) {
    return `${string} ORDER BY ${sort_by} ${sort_dir} OFFSET ${startIndex} LIMIT ${limit}`;
  }
  return `${string} OFFSET ${startIndex} LIMIT ${limit}`;
};

module.exports = withPaginSort;

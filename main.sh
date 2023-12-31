#!/bin/bash

#Ben Houghton - 2498662
#Celeste Artley - 2600927

current_repo=""

create_repository() {
  if [ ! -d "staging" ]; then
    # Create a new directory for the repository
    mkdir "$1"
    # Create a sub-directory for the repository to keep committed changes
    mkdir "$1/repo"
    # Create a staging area for uncommitted changes
    mkdir "$1/staging"

    mkdir "$1/editing"
    #stores in a text file what the current repo's path is.
    current_repo="$1"
    echo -e "\nRepo suscessfully create."
  else
    echo -e "\nRepo already Created"
  fi
}

select_repository(){
  #show all repos
  echo -e "\nAvailable repositories: "
  for dir in */; do
    if [ -d "$dir" ]; then
      echo "$dir"
    fi
  done

  echo -e "\n"

  #get repo name
  read -p "Enter the name of the repository you want to work with: " repo_name
  if [ -d "$repo_name" ]; then
    #set current_repo to selected
    current_repo="$repo_name"
    echo -e "\nRepository selected: $current_repo"
  else
    echo -e "\nRepository does not exist."
  fi
}

add_files() {
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi
  
  # List files in the repository directory
  echo -e "\nFiles in repository:"
  find $current_repo -maxdepth 1 -type f
  
  # Read user input for file selection
  read -p "Enter the name of the file you want to add: " selected_file

  # Check if the selected file exists in the repository using the find property
  if [ -f "$current_repo/$selected_file" ]; then
    # Add selected file to staging area
    mv "$current_repo/$selected_file" "$current_repo/editing/"
    echo -e "\nFile $selected_file has been added to editing area."
  else
    echo -e "\nFile does not exist."
  fi
}

edit_file(){
  #checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi

  #prints files in editing
  echo -e "\nFiles available for editing: "
  find $current_repo/editing -maxdepth 1 -type f

  read -p "Enter the name of the file to edit: " selected_file

  if [ ! -f "$current_repo/editing/$selected_file" ]; then
    echo "File $selected_file does not exist in the most recent commit."
    return 1  # Exit the function with an error status
  fi

  vim $current_repo/editing/$selected_file
}

checkout() {
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi

  # Get the most recent commit number (next commit - 1)
  next_commit=$(get_next_commit_number)
  latest_commit=$((next_commit - 1))
  latest_commit_dir="$current_repo/repo/$latest_commit"

  # Check if the latest commit directory exists
  if [ ! -d "$latest_commit_dir" ]; then
    echo "No commits available to check out."
    return 1  # Exit the function with an error status
  fi

  # List all files in the most recent commit
  echo "Files in the most recent commit ($latest_commit):"
  find $latest_commit_dir -maxdepth 1 -type f

  # Prompt the user to enter a file name to check out
  read -p "Enter file name to check out: " file_name

  file_path="$latest_commit_dir/$file_name"

  #allow editing of file
  chmod +w $file_path

  # Check if the selected file exists in the latest commit
  if [ ! -f "$file_path" ]; then
    echo "File $file_name does not exist in the most recent commit."
    return 1  # Exit the function with an error status
  fi

  # Copy the selected file to the working directory
  cp "$file_path" "$current_repo/editing"  # Assuming you want to copy to the current directory
}



checkin(){
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi

  #show all files in editing
  echo -e "\nFiles in editing: "
  find $current_repo/editing -maxdepth 1 -type f

  read -p "Enter file to checkin: " file_to_checkin

  #move editing to staging
  if [ -f "$current_repo/editing/$file_to_checkin" ]; then
    mv "$current_repo/editing/$file_to_checkin" "$current_repo/staging/"
    chmod -w $current_repo/staging/$file_to_checkin
    echo -e "\nFile checked in"
  else 
    echo -e "\nFile does not exist"
  fi
}

commit() {
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi
  
  # Get the next commit number
  commit_number=$(get_next_commit_number)
  commit_n=$((commit_number - 1))
  
  # Create a new directory for this commit
  commit_dir="$current_repo/repo/$commit_number"
  mkdir -p "$commit_dir"

  # Move files from staging area to this commit's directory
  mv "$current_repo/staging/"* "$commit_dir/"

  #copy existing repo ver
  cp "$current_repo/repo/$commit_n/"* "$commit_dir"

  # Delete all files in the staging area
  rm -f "$current_repo/staging/"*

  #Prompt for getting username
  read -p "Enter username: " username

  # Prompt for a commit message
  read -p "Enter a commit message: " commit_message

  # Log the commit message with the time
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  log_entry="$commit_number: $timestamp: User: $username , Commit message: $commit_message"
  write_log "$log_entry"
  mv "$current_repo"/changelog.txt "$current_repo"/repo/"$commit_number"
}


get_next_commit_number(){
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi
  if [ -f "$current_repo/log.txt" ]; then
    last_line=$(tail -n 1 "$current_repo/log.txt")
    number=$(echo "$last_line" | awk -F':' '{print $1}')
    let "number++"
    echo $number
  else
    echo "1"
  fi
}

check_differences() {
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi
  
  # Loop through each file in the staging area
  for file in staging/*; do
    # Get the file name from the path (note, basename deletes any prefix that ends with a / used for the diff  output)
    file_name=$(basename "$file")

    # Check if this file exists in the repo
    if [ -f "$current_repo/repo/$file_name" ]; then
      # Run diff command to compare the files and store that into the diff_output
      diff_output=$(diff "$file" "$current_repo/repo/$file_name")
      
      # Check if diff_output is empty (i.e., the files are identical)
      if [ -z "$diff_output" ]; then
        log_entry="No differences in $file_name"
        # Write that there were no diffrences in the file
        write_diff_log "$log_entry"
      else
        # Write the diffrences found in the log about what was changed
        log_entry="Differences found in $file_name: $diff_output"
        write_diff_log "$log_entry"
      fi
    else
      #this catches a situation where the file has not been commited yet
      log_entry="$file_name exists in staging but not in repository."
      write_diff_log "$log_entry"
    fi
  done
}

write_log() {
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi
  # code to write log
  echo "$1" >> "$current_repo/log.txt"
}
write_diff_log() {
  # Writes to difference log
  echo "$1" >> diff_log.txt
}

track_changes() {
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi
  
  next_commit=$(get_next_commit_number)
  last_commit=$((next_commit - 1))

  staging_dir="$current_repo/staging"
  
  # Check if the staging area exists and is not empty
  if [ -z "$(ls -A "$staging_dir")" ]; then
    echo "No files in staging."
    return  # Exit the function
  fi
  
  # Loop through each file in the staging area
  for file in "$staging_dir"/*; do
    file_name=$(basename "$file")
    
    # Check if this file exists in the last commit
    if [ -f "$current_repo/repo/$last_commit/$file_name" ]; then
      # Run diff command to compare the files and store that into diff_output
      diff_output=$(diff "$file" "$current_repo/repo/$last_commit/$file_name")
      
      # Check if diff_output is empty (i.e., the files are identical)
      if [ -z "$diff_output" ]; then
        log_entry="No differences in $file_name"
      else
        # Log the differences
        log_entry="Differences found in $file_name: $diff_output"
      fi
    else
      # File is new, so log that
      log_entry="New file $file_name added"
    fi
    
    # Write the log entry to changelog.txt in the repository root
    echo "$log_entry" >> "$current_repo/changelog.txt"
  done
}

compress_to_zip(){
  # checks current repo
  if [ -z "$current_repo" ]; then
    echo "No repository selected. Please select a repository first."
    return
  fi

  next_commit_no=$(get_next_commit_number)
  commit_no=$((next_commit_no -1 ))

  #zips most recent repo
  zip -r $current_repo/$current_repo.zip "$current_repo/repo/$commit_no"
}

while true; do
    echo "1: Initialize a new repository"
    if [ -z "$current_repo" ]; then
      echo "2: Select current repository (no repo selected)"
    else
      echo "2: Select current repository (currently: $current_repo )"
    fi
    echo "3: Add files to repo to edit"
    echo "4: Commit files to repository"
    echo "5: Check out file for edit"
    echo "6: Edit file in repo"
    echo "7: Check in file"
    echo "8: Compress repo to zip"
    echo -e "9: Exit\n"

    read -p "Enter your choice: " choice

    clear

    case $choice in
    1)
        read -p "Enter the name of the new repository: " repo_name
        create_repository "$repo_name"
        clear
        ;;
    2)
        select_repository
        ;;
    3)
        add_files
        clear
        ;;
    4)
        track_changes
        commit
        ;;
    5)
        checkout
        ;;
    6)
        edit_file
        ;;
    7)
        checkin
        ;;
    #i dont know if compress to zip works on qm computers as it
    #required me to install an extra library
    8)
        compress_to_zip
        ;;
    9)
      echo -e "\nExiting..."
      break
      ;;
    *)
        echo -e "\nInvalid choice."
        ;;
    esac
done